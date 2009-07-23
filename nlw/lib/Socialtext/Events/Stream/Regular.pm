package Socialtext::Events::Stream::Regular;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';
with qw(
    Socialtext::Events::Stream::HasPages
    Socialtext::Events::Stream::HasPeople
    Socialtext::Events::Stream::HasSignals
);

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::Events::Stream::Regular - The "All Events" Stream

=head1 DESCRIPTION

Convenience class that does the C<HasPages>, C<HasPeople> and C<HasSignals> Stream roles.

Cannot be composed with other Stream roles.

=head1 SYNOPSIS

For usage, see C<Socialtext::Events::Stream>
