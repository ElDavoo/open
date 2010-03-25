package Socialtext::Job::Upgrade::EnableGroups;
# @COPYRIGHT@
use Moose;
use Socialtext::Workspace;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

=head1 NAME

Socialtext::Job::Upgrade::EnableGroups - enable groups

=head1 SYNOPSIS

  Enable groups

=head1 DESCRIPTION

Enable group for all accounts according to business logic.

=cut

sub do_work {
    my $self = shift;

    Socialtext::Account->EnablePluginForAll('groups');

    $self->completed();
}

__PACKAGE__->meta->make_immutable;
1;
