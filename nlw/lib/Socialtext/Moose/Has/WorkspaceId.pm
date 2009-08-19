package Socialtext::Moose::Has::WorkspaceId;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn;
use namespace::clean -except => 'meta';

has 'workspace_id' => (
    is => 'rw', isa => 'Int',
    writer => '_workspace_id',
    trigger => \&_set_workspace_id,
    primary_key => 1,
    traits => [
        'Socialtext::Moose::SqlTable::Meta::Attribute::Trait::DbColumn'
    ],
);

has 'workspace' => (
    is => 'ro', isa => 'Socialtext::Workspace',
    lazy_build => 1,
);

sub _set_workspace_id {
    my $self = shift;
    $self->clear_workspace();
}

sub _build_workspace {
    my $self = shift;
    require Socialtext::Workspace;      # lazy-load
    my $ws_id     = $self->workspace_id();
    my $workspace = Socialtext::Workspace->new(workspace_id => $ws_id);
    unless ($workspace) {
        die "workspace_id=$ws_id no longer exists";
    }
    return $workspace;
}

no Moose::Role;
1;
