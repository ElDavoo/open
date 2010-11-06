package Socialtext::Job::SignalReIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

# Really, this class is just an alias for SignalIndex.
extends 'Socialtext::Job::SignalIndex';

__PACKAGE__->meta->make_immutable;
1;
