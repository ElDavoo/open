package Socialtext::UserWorkspaceRoleFactory;
# @COPYRIGHT@
use MooseX::Singleton;
use Socialtext::Log qw(st_log);
use namespace::clean -except => 'meta';

with qw/Socialtext::Moose::ObjectFactory/;

sub Builds_sql_for {'Socialtext::UserWorkspaceRole'}

sub EmitCreateEvent {

}

sub EmitDeleteEvent {

}

sub EmitUpdateEvent {

}

sub RecordCreateLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'ASSIGN' );
}

sub RecordDeleteLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'REMOVE' );
}

sub RecordUpdateLogEntry {
    my $self  = shift;
    my $uwr   = shift;
    my $timer = shift;

    $self->_write_log( $uwr, $timer, 'CHANGE' );
}

sub SetDefaultValues {
    my $self  = shift;
    my $proto = shift;

    $proto->{is_selected} ||= 1;
}

sub _write_log {
    my $self   = shift;
    my $uwr    = shift;
    my $timer  = shift;
    my $action = shift;

    st_log()->info($action . ',USER_ROLE,'
        . 'role:' . $uwr->role->name . ','
        . 'user:' . $uwr->user->username
        . '(' . $uwr->user_id . '),'
        . 'workspace:' . $uwr->workspace->name
        . '(' . $uwr->workspace->workspace_id . '),'
        . '[' . $timer->elapsed . ']'
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
