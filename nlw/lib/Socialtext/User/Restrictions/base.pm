package Socialtext::User::Restrictions::base;

use Moose::Role;
use Socialtext::Date;
use Socialtext::MooseX::Types::Pg;
use Socialtext::User::Restrictions;

requires 'restriction_type';

has 'user_id' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
);

has 'user' => (
    is         => 'ro',
    isa        => 'Socialtext::User',
    lazy_build => 1,
);
sub _build_user {
    my $self = shift;
    my $user = Socialtext::User->new(user_id => $self->user_id);
}

has 'token' => (
    is       => 'ro',
    isa      => 'Str',
    writer   => '_set_token',
);

has 'expires_at' => (
    is       => 'ro',
    isa      => 'Pg.DateTime',
    writer   => '_set_expires_at',
    required => 1,
    coerce   => 1,
);

has 'workspace_id' => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

sub CreateOrReplace {
    my $class = shift;
    my %opts  = @_;
    Socialtext::User::Restrictions->CreateOrReplace( {
        %opts,
        restriction_type => $class->restriction_type,
    } );
}

sub update {
    my $self  = shift;
    my $proto = shift;
    Socialtext::User::Restrictions->Update($self, $proto);
}

sub clear {
    my $self = shift;
    Socialtext::User::Restrictions->Delete($self);
}

sub has_expired {
    my $self       = shift;
    my $now        = Socialtext::Date->now;
    my $expires_at = $self->expires_at;
    return $expires_at < $now;
}

sub renew {
    my $self = shift;
    my $when = Socialtext::User::Restrictions->default_expires_at;
    $self->update( { expires_at => $when } );
}

1;
