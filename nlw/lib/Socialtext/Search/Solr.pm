package Socialtext::Search::Solr;
use Moose;
use WebService::Solr;
use namespace::clean -except => 'meta';

has 'ws_name' => (is => 'ro', isa => 'Str', required => 1);
has 'workspace' => (is => 'ro', isa => 'Object', lazy_build => 1);
has 'hub'       => (is => 'ro', isa => 'Object',           lazy_build => 1);
has 'solr'      => (is => 'ro', isa => 'WebService::Solr', lazy_build => 1);

sub _build_workspace {
    my $self = shift;
    my $ws_name = $self->ws_name;
    my $ws = Socialtext::Workspace->new( name => $ws_name );
    die "Cannot create workspace '$ws_name'" unless defined $ws;
    return $ws;
}

sub _build_hub {
    my $self = shift;
    my $ws_name = $self->ws_name;

    my $hub = Socialtext::Hub->new(
        current_workspace => $self->workspace,
        current_user => Socialtext::User->SystemUser,
    );
    $hub->registry->load;

    return $hub;
}

sub _build_solr {
    my $self = shift;
    return WebService::Solr->new(
        Socialtext::AppConfig->solr_base,
        { autocommit => 0 },
    );
}

__PACKAGE__->meta->make_immutable;
1;
