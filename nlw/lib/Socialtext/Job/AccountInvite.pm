package Socialtext::Job::AccountInvite;
# @COPYRIGHT@
use Socialtext::User;
use Socialtext::Account;
use Socialtext::AccountInvitation;
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

has sender => (
    is => 'ro', isa => 'Socialtext::User',
    lazy_build => 1,
);

has account => (
    is => 'ro', isa => 'Socialtext::Account',
    lazy_build => 1,
);

sub _build_sender {
    my $self = shift;
    return Socialtext::User->new( user_id => $self->arg->{sender_id} );
}

sub _build_account {
    my $self = shift;
    return Socialtext::Account->new( account_id => $self->arg->{account_id} );
}

sub do_work {
    my $self = shift;

    my $account = $self->account;
    my $user    = $self->user;

    unless ( $account->has_user($user) ) {
        my $msg = "User " . $user->user_id 
            . " is not in account " . $account->account_id;
        return $self->failed($msg, 255);
    }

    eval {
        my $invitation = Socialtext::AccountInvitation->new(
            account     => $account,
            from_user   => $self->sender,
            extra_text  => $self->arg->{extra_text},
        );

        # {bz: 3357} - Somehow the constructor does not set layout of $invitation
        # properly; manually re-assign the fields until we get a cycle to investigate.
        $invitation->{from_user} = $self->sender;
        $invitation->{extra_text} = $self->arg->{extra_text};

        $invitation->invite_notify($user);
    };
    if ( my $e = $@ ) {
        return $self->failed($e, 255);
    }

    $self->completed();
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::AccountInvite - Send an invite to a user for an account.

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::AccountInvite',
        {
            account_id => 1,
            user_id    => 13,
            sender_id  => 169,
        },
    );

=head1 DESCRIPTION

Schedule a job to be run by TheCeq which will send an e-mail message to the
User to indicate to them that they have been invited to the given Account.

=cut
