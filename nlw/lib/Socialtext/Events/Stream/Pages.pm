package Socialtext::Events::Stream::Pages;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Events::Stream';
with 'Socialtext::Events::Stream::HasPages';

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::Events::Stream::Pages - Page events stream.

=head1 DESCRIPTION

Convenience class that does the C<HasPages> Stream role.

Cannot be composed with other Stream roles.

=head1 SYNOPSIS

For usage, see C<Socialtext::Events::Stream>
