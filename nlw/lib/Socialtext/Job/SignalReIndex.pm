package Socialtext::Job::SignalReIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job::SignalIndex';
with 'Socialtext::ReIndexJob';

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Job::SignalReIndex - An alias for Socialtext::Job::SignalIndex

=head1 SYNOPSIS

    use Socialtext::JobCreator;

    Socialtext::JobCreator->insert(
        'Socialtext::Job::SignalReIndex => { %args }
    );

=head1 DESCRIPTION

Functionally identical to Socialtext::Job::SignalIndex. For all intents and
purposes, SignalIndex should be used. In the special case where we need to
know when we're RE-indexing, eg, when pushing an update to our DB/search
engine layout, SignalReIndex should be used.

=cut
