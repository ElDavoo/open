package Test::Socialtext::AccountContext;
# @COPYRIGHT@
use Test::Socialtext;
use Socialtext::Account;
use File::Find::Rule;
use File::Basename;
use Moose;
use namespace::clean -except => 'meta';

has 'export_name' => (is => 'ro', isa => 'Str', required => 1);
has 'features'    => (is => 'ro', isa => 'HashRef', lazy_build => 1);
has 'registry'    => (is => 'ro', isa => 'HashRef', lazy_build => 1);

sub test_plan {
    my $self = shift;
    my $tests = 0;
    map { $tests += $_->Tests() } values %{$self->features};

    return $tests;
}

sub _build_features {
    my $self = shift;

    (my $dir = __FILE__) =~ s/\.pm$//;
    my @feature_names = map { basename($_, '.pm') }
        File::Find::Rule->file()->name(qr/.+\.pm$/)->in("$dir/features");

    my %features = ();
    for my $name (@feature_names) {
        my $feature_class = join('::', __PACKAGE__, 'features', $name);
        eval "require $feature_class"
            or die "Cannot load $name ($feature_class): $@\n";
        $features{$name} = $feature_class;
    }
    return \%features;
}

sub _build_registry {
    my $self = shift;
    my $pkg = __PACKAGE__;

    my %registry = ();
    for my $name (keys %{$self->features}) {
        my $feature_class = $self->features->{$name};
        my $feature = $feature_class->new(context => $self);
        $registry{$name} = $feature;
    }

    return \%registry;
}

sub prepare {
    my $self = shift;
    $self->_all_features_do(sub {
        my $feature = shift;
        $feature->prepare();
    });
}

sub validate {
    my $self = shift;
    $self->_all_features_do(sub {
        my $feature = shift;
        $feature->validate();
    });
}

sub clear_shares {
    my $self = shift;
    $self->_all_features_do(sub {
        my $feature = shift;
        diag "emptying share for ". ref($feature);
        $feature->clear_share();
    });
}

sub _all_features_do {
    my $self = shift;
    my $coderef = shift;
    for my $feature (values %{$self->registry}) {
        $coderef->($feature);
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
