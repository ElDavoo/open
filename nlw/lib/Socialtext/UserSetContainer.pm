package Socialtext::UserSetContainer;
# @COPYRIGHT@
use Moose::Role;
use Socialtext::UserSet;
use Socialtext::SQL qw(sql_execute);
use Socialtext::l10n qw/loc/;
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

=head1 DESCRIPTION

Adds a C<user_set> attribute to your class that automatically constructs the 
L<Socialtext::UserSet> object for this container.

Requires that the base class has a C<user_set_id> accessor.

Instances maintain a weak reference to the owning object.

=cut
