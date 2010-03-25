package Socialtext::Job::Upgrade::EnableSocialcalc;
# @COPYRIGHT@
use Moose;
use Socialtext::Workspace;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

=head1 NAME

Socialtext::Job::Upgrade::EnableSocialcalc - enable socialcalc

=head1 SYNOPSIS

  Enable socialcalc

=head1 DESCRIPTION

Enable socialcalc for all workspaces according to business logic.

=cut

sub do_work {
    my $self = shift;

    Socialtext::Workspace->EnablePluginForAll('socialcalc');

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
