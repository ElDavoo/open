package Socialtext::UserWorkspaceRoleFactory;
# @COPYRIGHT@
use MooseX::Singleton;
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
    
}

sub RecordDeleteLogEntry {
    
}

sub RecordUpdateLogEntry {
    
}

sub SetDefaultValues {

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
