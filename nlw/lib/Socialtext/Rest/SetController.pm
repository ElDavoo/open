package Socialtext::Rest::SetController;
# @COPYRIGHT@
use Moose;
use Carp 'croak';
use Socialtext::Role;
use namespace::clean -except => 'meta';

my @valid_actions = qw(add update remove); # 'skip' exists for internal use.
my @valid_scopes  = qw(user group);

has 'actor' => (
    is => 'ro', isa => 'Socialtext::User',
    required => 1,
);

has 'container' => (
    is => 'ro', isa => 'Socialtext::UserSetContainer',
    required => 1,
);

has 'scopes' => (
    is => 'rw', isa => 'ArrayRef',
    required => 1, default => sub { [@valid_scopes] },
    trigger => \&scopes_are_valid,
    auto_deref => 1,
);

has 'actions' => (
    is => 'rw', isa => 'ArrayRef',
    required => 1, default => sub { [@valid_actions] },
    trigger => \&actions_are_valid,
    auto_deref => 1,
);

has 'hooks' => (
    is => 'rw', isa => 'HashRef',
    required => 1, default => sub { +{} },
);

sub actions_are_valid {
    my $self    = shift;
    my $actions = shift;

    for my $action (@$actions) {
        croak "action $action is not valid"
            unless grep { $_ eq $action } @valid_actions;
    }
}

sub scopes_are_valid {
    my $self   = shift;
    my $scopes = shift;

    for my $scope (@$scopes) {
        croak "scope '$scope' is not valid"
            unless grep { $_ eq $scope } @valid_scopes;
    }
}

sub alter_members {
    my $self     = shift;
    my $requests = shift;

    for my $req (@$requests) {
        $self->alter_one_member($req);
    }
}

sub alter_one_member {
    my $self = shift;
    my @req  = (@_ == 1) ? %{$_[0]} : @_;

    croak "request is null" unless scalar(@req);

    my ($scope,$thing_key)  = $self->request_scope(@req);
    my $role                = $self->request_role(@req);
    my $thing               = $self->request_thing($thing_key, @req);
    my $action              = $self->request_action($scope, $thing, $role);
    return undef if $action eq 'skip';

    my $req = {$scope => $thing, role => $role, actor => $self->actor};
    $self->execute($action, $scope, $req);

    return $self->run_post_hook($action, $scope, $req);
}

sub run_post_hook {
    my $self   = shift;
    my $scope  = shift;
    my $action = shift;
    my $req    = shift;

    my $hook_idx = join('_', 'post', $action, $scope);
    if ( my $hook = $self->hooks->{$hook_idx} ) {
        return $hook->($req);
    }
    return undef;
}

{
    my $to_exe = {
        user => {
            add    => sub { shift->add_user(@_) },
            remove => sub { shift->remove_user(@_) },
            update => sub { shift->assign_role_to_user(@_) },
        },
        group => {
            add    => sub { shift->add_group(@_) },
            remove => sub { shift->remove_group(@_) },
            update => sub { shift->assign_role_to_group(@_) },
        },
    };

    sub execute {
        my $self   = shift;
        my $action = shift;
        my $scope  = shift;
        my $req    = shift;

        my $to_exe = $to_exe->{$scope}{$action};
        croak "nothing to do for '$scope $action'"
            unless $to_exe;

        return $to_exe->($self->container, $req);
    }
}

{
    my $realize = {
        username => sub { Socialtext::User->Resolve($_[0]) },
        user_id  => sub { Socialtext::User->Resolve($_[0]) },
        group_id => sub {
            eval{Socialtext::Group->GetGroup(group_id => $_[0])} },
    };

    sub request_thing {
        my $self  = shift;
        my $key   = shift;
        my %req   = @_;

        my $realizor = $realize->{$key};
        croak "cannot realize '$key : $req{$key}'" unless $realizor;

        my $thing = $realizor->($req{$key});
        croak "no result for '$key : $req{$key}'"
            unless $thing;
        return $thing;
    }
}

sub request_role {
    my $self = shift;
    my %req  = @_;

    my $role_name = $req{role_name};
    return undef unless $role_name;

    my $role = Socialtext::Role->new(name => $req{role_name});
    croak "no such role '$role_name'" unless $role;

    return $role;
}

sub request_action {
    my $self  = shift;

    my $action = $self->_real_request_action(@_);
    croak "action '$action' is not allowed"
        unless $action eq 'skip' || grep { $action eq $_ } $self->actions;

    return $action;
}

sub _real_request_action {
    my $self  = shift;
    my $scope = shift;
    my $thing = shift;
    my $role  = shift;

    my $checker = "role_for_$scope";
    my $has     = $self->container->$checker($thing, direct => 1);

    if ($has) {
        return 'remove' unless $role;
        return 'skip' if $has->role_id == $role->role_id;
        return 'update';
    }
    else {
        return 'add' if $role;
        return 'skip';
    }
}

{ 
    my $scopes_for_key = {
        user_id  => 'user',
        username => 'user',
        group_id => 'group',
    };

    sub request_scope {
        my $self = shift;
        my @req  = @_;

        for my $key (@req) {
            next unless $key;

            my $scope = $scopes_for_key->{$key};
            next unless $scope;

            croak "scope for key '$key' is illegal"
                unless grep { $_ eq $scope } $self->scopes;

            return ($scope => $key);
        }
        croak "no scope found for request";
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Rest::SetController - A generic interface for ReST interaction
with user sets.

=head1 SYNOPSIS

    use Socialtext::Rest::SetController;

    my $controller = Socialtext::Rest::SetController->new(
        container => $workspace,
        actor     => $user,
        scope     => 'user',
    );

    # Alter one user
    $controller->alter_one_member(
        user_id   => 13,
        role_name => 'member',
    );

    # Alter many users
    $controller->alter_members([
        { username => 'bob@example.com', role_name => 'member' },
        { user_id  => 15               , role_name => 'admin' },
        { user_id  => 21               , role_name => undef },
    ]);

=head1 DESCRIPTION

C<Socialtext::Rest::SetController> is a generic, easily-configurable interface
that can be used to build out ReST calls to a
C<Socialtext::UserSetContainer>'s sets, be they Users or Groups.

=cut
