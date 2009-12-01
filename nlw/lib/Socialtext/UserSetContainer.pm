package Socialtext::UserSetContainer;
# @COPYRIGHT@
use Moose::Role;
use Carp qw/croak/;
use Socialtext::UserSet;
use Socialtext::SQL qw(sql_execute sql_singlevalue);
use Socialtext::l10n qw/loc/;
use Socialtext::UserSet ();
use Socialtext::Exceptions qw/param_error/;
use Socialtext::Cache ();
use Socialtext::MultiCursor;
use Socialtext::Timer qw/time_scope/;
use List::MoreUtils qw/any/;
use namespace::clean -except => 'meta';

requires 'user_set_id';

has 'user_set' => (
    is => 'ro', isa => 'Socialtext::UserSet',
    lazy_build => 1,
);

sub _build_user_set {
    my $self = shift;
    return Socialtext::UserSet->new(
        owner => $self,
        owner_id => $self->user_set_id,
    );
}

sub plugins_enabled {
    my $self = shift;
    my $authz = Socialtext::Authz->new();
    return $authz->plugins_enabled_for_user_set(user_set => $self, @_);
}

sub is_plugin_enabled {
    my ($self, $plugin_name) = @_;
    my $authz = Socialtext::Authz->new();
    return $authz->plugin_enabled_for_user_set(
        user_set    => $self,
        plugin_name => $plugin_name
    );
}

sub enable_plugin {
    my ($self, $plugin, $scope) = @_;
    $scope ||= 'account';

    require Socialtext::Pluggable::Adapter;
    my $plugin_class = Socialtext::Pluggable::Adapter->plugin_class($plugin);
    $self->_check_plugin_scope($plugin, $plugin_class, $scope);

    return if $self->is_plugin_enabled($plugin);

    Socialtext::Pluggable::Adapter->EnablePlugin($plugin => $self);

    sql_execute(q{
        INSERT INTO user_set_plugin VALUES (?,?)
    }, $self->user_set_id, $plugin);

    Socialtext::Cache->clear('authz_plugin');

    for my $dep ($plugin_class->dependencies, $plugin_class->enables) {
        $self->enable_plugin($dep);
    }
}

sub disable_plugin {
    my ($self, $plugin, $scope) = @_;
    $scope ||= 'account';

    require Socialtext::Pluggable::Adapter;
    my $plugin_class = Socialtext::Pluggable::Adapter->plugin_class($plugin);
    $self->_check_plugin_scope($plugin, $plugin_class, $scope);

    # Don't even bother disabling deps if the plugin is already enabled
    return unless $self->is_plugin_enabled($plugin);

    Socialtext::Pluggable::Adapter->DisablePlugin($plugin => $self);

    sql_execute(q{
        DELETE FROM user_set_plugin
        WHERE user_set_id = ? AND plugin = ?
    }, $self->user_set_id, $plugin);

    Socialtext::Cache->clear('authz_plugin');

    # Disable any reverse depended packages
    for my $rdep ($plugin_class->reverse_dependencies) {
        $self->disable_plugin($rdep);
    }
}

sub _check_plugin_scope {
    my ($self,$plugin,$plugin_class,$scope) = @_;

    die loc("The [_1] plugin can not be set at the [_2] scope", $plugin, $scope) . "\n"
        unless $plugin_class->scope eq $scope;
}

sub PluginsEnabledForAll {
    my $class = shift;
    my $table = shift;
    my $sth = sql_execute(
        q{SELECT field FROM "System" where field like '%-enabled-all'});
    my @plugins = map { $_->[0] =~ m/(.+)-enabled-all/; $1 }
                    @{ $sth->fetchall_arrayref };
    my @enabled_for_all;
    for my $plugin (@plugins) {
        my $count = sql_singlevalue(<<EOT);
SELECT count(*) FROM "$table"
    WHERE user_set_id NOT IN (
        SELECT user_set_id FROM user_set_plugin
            WHERE plugin = '$plugin'
    )
EOT
        push @enabled_for_all, $plugin if $count == 0;
    }
    return @enabled_for_all;
}

sub role_default {
    my ($self,$thing) = @_;
    return Socialtext::Role->Member;
}

before 'add_role' => \&_role_change_checker;
sub add_role {
    my $self = shift;
    my %p = @_;
    my $thing = $p{object};
    my $role = $p{role} || $self->role_default($thing);
    $role = Socialtext::Role->new(name => $role)
        unless blessed($role);

    $self->role_change_check($p{actor},'add',$thing,$role);
    eval { $self->user_set->add_object_role($thing, $role) };
    if ($@) {
        if ($@ =~ /constraint/i) {
            die "could not add role: object already exists with some role";
        }
        die $@;
    }

    eval { $self->role_change_event($p{actor},'add',$thing,$role) };
    return;
}

before 'assign_role' => \&_role_change_checker;
sub assign_role {
    my $self = shift;
    my %p = @_;
    my $thing = $p{object};
    my $role = $p{role} || $self->role_default($thing);
    $role = Socialtext::Role->new(name => $role)
        unless blessed($role);

    my $uset = $self->user_set;
    my $change;
    if ($uset->directly_connected($thing->user_set_id => $self->user_set_id)) {
        $change = 'update';
        $self->role_change_check($p{actor},$change,$thing,$role);
        $uset->update_object_role($thing, $role);
    }
    else {
        $change = 'add';
        $self->role_change_check($p{actor},$change,$thing,$role);
        $uset->add_object_role($thing, $role);
    }

    eval { $self->role_change_event($p{actor},$change,$thing,$role) };
    return;
}

before 'remove_role' => \&_role_change_checker;
sub remove_role {
    my $self = shift;
    my %p = @_;

    my $thing = $p{object};
    $self->role_change_check($p{actor},'remove',$thing);
    eval { $self->user_set->remove_object_role($thing) };
    if ($@) {
        if ($@ =~ /edge \d+,\d+ does not exist/) {
            die "object not in this user set, ".
                "set:".$self->user_set_id." obj:".$thing->user_set_id;
        }
        die $@;
    }

    eval { $self->role_change_event($p{actor},'remove',$thing) };
    return;
}

sub _role_change_checker {
    my $self = shift;
    my %p = @_;

    if ($p{role}) {
        param_error "role parameter must be a Socialtext::Role"
            unless (blessed $p{role} && $p{role}->isa('Socialtext::Role'));
        param_error 'Cannot explicitly assign a default role type to a user'
            if $p{role}->used_as_default;
    }

    param_error "requires an actor parameter that's a Socialtext::User"
        unless (blessed($p{actor}) && $p{actor}->isa('Socialtext::User'));

    my $o = $p{object};
    param_error "object parameter must be blessed" unless blessed $o;
    unless ($o->isa('Socialtext::User') ||
            $o->isa('Socialtext::UserSetContainer'))
    {
        param_error "object parameter must be a Socialtext::User or Socialtext::UserSetContainer";
    }

    if ($o->isa('Socialtext::User') && $o->is_system_created) {
        param_error 'Cannot give a role to a system-created user';
    }
}

sub role_change_check {
    my ($self,$actor,$change,$thing,$role) = @_;
    return;
}

sub role_change_event {
    my ($self,$actor,$change,$thing,$role) = @_;

    Socialtext::Cache->clear('authz_plugin');

    Socialtext::Cache->clear('ws_roles')
        unless $self->isa('Socialtext::Account');

    if ($thing->isa('Socialtext::User')) {
        require Socialtext::JSON::Proxy::Helper;
        Socialtext::JSON::Proxy::Helper->ClearForUsers($thing->user_id);
    }
}

sub add_user {
    my ($self,%p) = @_;
    my $actor = $p{actor} || Socialtext::User->SystemUser;
    my $user = $p{user};
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    $self->add_role(
        actor => $actor,
        object => $user,
        role => $p{role},
    );
}

sub assign_role_to_user {
    my ($self,%p) = @_;
    my $user = $p{user};
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    my $actor = $p{actor} || Socialtext::User->SystemUser;
    $self->assign_role(
        actor => $actor,
        object => $user,
        role => $p{role},
    );
}

sub remove_user {
    my ($self, %p) = @_;
    my $uset = $self->user_set;
    my $user = $p{user};
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    my $actor = $p{actor} || Socialtext::User->SystemUser;

    eval {
        $self->remove_role(
            actor => $actor,
            object => $user,
            role => $p{role},
        );
    };
    if ($@) {
        return if ($@ =~ /object not in this user set/);
        die $@;
    }
}

sub has_user {
    my ($self, $user, %p) = @_;
    my $uset = $self->user_set;
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    my $meth = $p{direct} ? 'directly_connected' : 'connected';
    return $uset->$meth($user->user_set_id => $self->user_set_id);
}

sub role_for_user {
    my ($self, $user, %p) = @_;
    my $uset = $self->user_set;
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    if ($p{direct}) {
        return $uset->direct_role($user->user_set_id => $self->user_set_id);
    }
    else {
        my @roles = $uset->roles($user->user_set_id => $self->user_set_id);
        # FIXME: this sort function is lame; it doesn't consider permissions
        # at all and it uses hash params pointlessly.
        @roles = Socialtext::Role->SortByEffectiveness(roles => \@roles);
        return @roles if wantarray;
        return $roles[1];
    }
}

sub user_has_role {
    my ($self,%p) = @_;
    my $user = $p{user};
    croak "must supply a user" unless ($user && $user->isa('Socialtext::User'));
    my $role = $p{role};
    croak "must supply a user" unless ($role && $role->isa('Socialtext::Role'));
    my @roles = $self->user_set->roles($user->user_set_id => $self->user_set_id);
    return any {$_ eq $role} @roles;
}

sub user_count {
    my ($self,%p) = @_;
    my $t = time_scope('uset_user_count');
    my $meth = $p{direct} ? 'direct_object_user_count' : 'object_user_count';
    return $self->user_set->$meth();
}

sub user_ids {
    my ($self,%p) = @_;
    my $t = time_scope('uset_user_ids');
    my $meth = $p{direct} ? 'direct_object_user_ids' : 'object_user_ids';
    my $ids = $self->user_set->$meth();
    return $ids;
}

sub users {
    my ($self,%p) = @_;
    my $t = time_scope('uset_users');
    my $meth = $p{direct} ? 'direct_object_user_ids' : 'object_user_ids';
    my $ids = $self->user_set->$meth();
    return Socialtext::MultiCursor->new(
        iterables => $ids,
        apply     => sub {
            return Socialtext::User->new(user_id => $_[0]);
        },
    );
}

sub user_roles {
    my ($self,%p) = @_;
    my $t = time_scope('uset_user_roles');
    my $meth = $p{direct} ? 'direct_object_user_roles' : 'object_user_roles';
    my $rows = $self->user_set->$meth();
    return Socialtext::MultiCursor->new(
        iterables => $rows,
        apply     => sub {
            return [
                Socialtext::User->new(user_id => $_[0]),
                Socialtext::Role->new(role_id => $_[1]),
            ];
        },
    );
}

1;

__END__

=head1 NAME

Socialtext::UserSetContainer - Role for things containing UserSets

=head1 SYNOPSIS

  package MyContainer;
  use Moose;
  has 'user_set_id' => (..., isa => 'Int');
  with 'Socialtext::UserSetContainer';

  my $o = MyContainer->new(); # or w/e
  my $uset = $o->user_set;

  $o->is_plugin_enabled('people');
  $o->enable_plugin('people');
  $o->disable_plugin('people');

  $o->add_role(
    actor => $user,
    object => $some_user_or_set,
    role => Socialtext::Role->Member,
  );
  $o->assign_role(
    actor => $user,
    object => $some_user_or_set,
    role => Socialtext::Role->Admin,
  );
  $o->remove_role(
    actor => $user,
    object => $some_user_or_set,
  );

=head1 DESCRIPTION

Adds a C<user_set> attribute to your class that automatically constructs the 
L<Socialtext::UserSet> object for this container.

Requires that the base class has a C<user_set_id> accessor.

Instances maintain a weak reference to the owning object.

=cut
