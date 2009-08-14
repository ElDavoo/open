package Socialtext::Job::GroupRefresh;
# @COPYRIGHT@
use Moose;
use Socialtext::Group;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

has proto_group => (
    is => 'ro', isa => 'HashRef',
    lazy_build => 1,
);

# If we were to fetch the group directly, we may fire off an unintented
# refresh, so let's peek at it's prototype.
sub _build_proto_group {
    my $self = shift;
    my $group_id = $self->arg->{group_id};

    my $proto_group =
        Socialtext::Group->GetProtoGroup( { group_id => $group_id } );

    unless ( $proto_group ) {
        my $msg = "group_id $group_id does not exist\n";
        $self->permanent_failure( $msg );
        die "$msg\n";
    }

    return $proto_group;
}

sub do_work {
    my $self          = shift;
    my $proto         = $self->proto_group;
    my $job_cache_key = $self->arg->{'cached_at'};

    # Compare the times as _strings_, it's not always right otherwise.
    if ( $proto->{cached_at}->hires_epoch eq $job_cache_key ) {
        # always force the refresh from the underlying store
        local $Socialtext::Group::Factory::CacheEnabled = 0;
        local $Socialtext::Group::Factory::Asynchronous = 0;

        # refresh the Group
        Socialtext::Group->GetGroup( { group_id => $proto->{group_id} } );
    }

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
