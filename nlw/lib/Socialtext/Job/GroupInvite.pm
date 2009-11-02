package Socialtext::Job::GroupInvite;
# @COPYRIGHT@
use Socialtext::User;
use Socialtext::Group;
use Socialtext::GroupInvitation;
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

has sender => (
    is => 'ro', isa => 'Socialtext::User',
    lazy_build => 1,
);

has group => (
    is => 'ro', isa => 'Socialtext::Group',
    lazy_build => 1,
);

sub _build_sender {
    my $self = shift;
    return Socialtext::User->new( user_id => $self->arg->{sender_id} );
}

sub _build_group {
    my $self = shift;
    return Socialtext::Group->GetGroup( driver_unique_id => $self->arg->{group_id} );
}

sub do_work {
    my $self  = shift;
    my $group = $self->group;
    my $user  = $self->user;

    unless ( $group->has_user($user) ) {
        my $msg = "User " . $user->user_id 
            . " is not in group " . $group->group_id;
        $self->failed($msg, 255);
    }

    eval {
        Socialtext::GroupInvitation->new(
            group      => $group,
            from_user  => $self->sender,
            extra_text => $self->arg->{extra_text},
        )->invite_notify($user);
    };
    if ( my $e = $@ ) {
        $self->failed($e, 255);
    }

    $self->completed();
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::GroupInvite - Send an invite to a user for an group.

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::GroupInvite',
        {
            group_id => 1,
            user_id    => 13,
            sender_id  => 169,
        },
    );

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will send an e-mail message to the
User to indicate to them that they have been invited to the given Group.

=cut
