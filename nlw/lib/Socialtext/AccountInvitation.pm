package Socialtext::AccountInvitation;
# @COPYRIGHT@
use Moose;
use Socialtext::l10n qw(loc);
use namespace::clean -except => 'meta';

extends 'Socialtext::Invitation';

our $VERSION = '0.01';

has 'account' => (
    is       => 'ro', isa => 'Socialtext::Account',
    required => 1,
);

sub queue {
    my $self      = shift;
    my $invitee   = shift;
    my %user_args = @_;

    my $acct = $self->account;
    my $user = Socialtext::User->new(
        email_address => $invitee
    );

    $user ||= Socialtext::User->create(
        username => $invitee,
        email_address => $invitee,
        created_by_user_id => $self->from_user->user_id,
        primary_account_id => $acct->account_id,
        %user_args,
    );

    $user->set_confirmation_info()
        unless $user->has_valid_password();

    $acct->assign_role_to_user(
        user => $user,
        role => Socialtext::Role->Member()
    );

    Socialtext::JobCreator->insert(
        'Socialtext::Job::Invite',
        {
            account_id      => $acct->account_id,
            user_id         => $user->user_id,
            sender_id       => $self->from_user->user_id,
            extra_text      => $self->extra_text,
        }
    );
}

sub _name {
    my $self = shift;
    return $self->account->name;
}

sub _subject {
    my $self = shift;
    loc("I'm inviting you into the [_1] network", $self->account->name);
}

sub _template_type { 'account' }

sub _template_args {
    my $self = shift;
    return (
        account_name => $self->account->name,
        account_uri  => Socialtext::URI::uri(path => '/'),
    );
}

__PACKAGE__->meta->make_immutable;
1;
