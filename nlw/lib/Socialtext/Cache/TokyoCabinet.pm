package Socialtext::Cache::TokyoCabinet;
use Moose;
use lib '/opt/tokyocabinet/lib/perl5';
use TokyoTyrant;
use Socialtext::Paths;
use Storable ();
use namespace::clean -except => 'meta';

# defaults, can be overridden via constructor
our $TYRANT_HOST = 'localhost'; # set to path for unix socket
our $TYRANT_PORT = '1978';      # set to 0 for unix socket

# (cargo-cult) pre-load Storable:
Storable::thaw Storable::nfreeze [];

has 'namespace' => (is => 'ro', isa => 'Str');

has 'stats' => (
    is => 'rw', isa => 'HashRef',
    default => sub {{}},
    writer => '_stats',
);

has 'tt' => (
    is => 'ro', isa => 'TokyoTyrant::RDB',
    lazy_build => 1,
);

has 'host' => (is => 'ro', isa => 'Str', default => sub { $TYRANT_HOST });
has 'port' => (is => 'ro', isa => 'Int', default => sub { $TYRANT_PORT });

sub _build_tt {
    my $self = shift;
    my $tt = TokyoTyrant::RDB->new;
    unless ($tt->open($self->host,$self->port)) {
        die "Can't connect to tyrant: ".$tt->errmsg($tt->ecode);
    }
    return $tt;
}

before 'clear_tt' => sub {
    my $self = shift;
    return unless $self->has_tt;
    my $tt = $self->tt;
    if (!$tt->close()) {
        die "Can't close tyrant: ".$tt->errmsg($tt->ecode);
    }
};

sub DEMOLISH {
    my $self = shift;
    $self->clear_tt; # so it gets closed
}

sub _pack {
    defined($_[0]) ? Storable::nfreeze(ref($_[0]) ? $_[0] : \$_[0]) : '';
}

sub _unpack (\$) {
    return unless length(${$_[0]}); # empty string is undef
    my $ref = Storable::thaw ${$_[0]};
    return ref($ref) eq 'SCALAR' ? $$ref : $ref;
}

sub get {
    my ($self, $key) = @_;
    my $tt = $self->tt;

    $key = $self->namespace."\t".$key;
    my $thing = $tt->get($key);
    if (!defined($thing)) {
        my $ec = $tt->ecode;
        die "Can't get key: ".$tt->errmsg($ec)
            unless $ec == $tt->ENOREC;
        $self->stats->{miss}++;
        return;
    }

    $self->stats->{hit}++;
    return _unpack $thing;
}

# TODO: mget

sub set {
    my ($self, $key) = @_;
    my $tt = $self->tt;
    $key = $self->namespace."\t".$key;
    my $val = ref($_[2]) ? $_[2] : \$_[2];
    $tt->put($key, _pack($val))
        or die "Can't set key: ".$tt->errmsg($tt->errno);
    $self->stats->{set}++;
    return;
}

sub mset {
    my ($self, $things) = @_;
    my $pfx = $self->namespace."\t";
    my @args;
    for my $key (keys %$things) {
        my $val = ref($things->{$key}) ? $things->{$key} : \$things->{$key};
        push @args, $pfx.$key, _pack($val);
    }
    my $tt = $self->tt;
    $tt->misc('putlist',\@args)
        or die "Can't mset: ".$tt->errmsg($tt->errno);
    $self->stats->{set} += scalar keys %$things;
    return;
}

sub remove {
    my ($self, $key) = @_;
    my $tt = $self->tt;
    $key = $self->namespace."\t".$key;
    $tt->out($key)
        or die "Can't remove key: ".$tt->errmsg($tt->errno);
    $self->stats->{remove}++;
    return;
}

sub mremove {
    my $self = shift;
    my $keys = ref($_[0]) ? $_[0] : \@_;
    return unless @$keys;
    my $tt = $self->tt;
    my $pfx = $self->namespace."\t";
    my @mapped = map { $pfx.$_ } @$keys;
    $tt->misc('outlist',\@mapped)
        or die "Can't mremove: ".$tt->errmsg($tt->errno);
    $self->stats->{remove} += @mapped;
}

sub get_keys {
    my ($self) = @_;
    my $tt = $self->tt;
    my $keys = $tt->fwmkeys($self->namespace."\t");
    return wantarray ? @$keys : $keys;
}

sub clear {
    my ($self,$force) = @_;
    if ($force) {
        my $tt = $self->tt;
        my $keys = $tt->fwmkeys($self->namespace."\t");
        $tt->misc('outlist',$keys)
            or die "Can't force clear: ".$tt->errmsg($tt->errno);
    }
    $self->clear_tt; # close the connection
    $self->_stats({});
    return;
}

__PACKAGE__->meta->make_immutable;
1;
