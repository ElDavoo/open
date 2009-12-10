package Socialtext::MooseX::Types::UniStr;
# @COPYRIGHT@
use strict;
use warnings;
use Moose::Util::TypeConstraints;
use Encode ();
use namespace::clean -except => 'meta';

subtype 'UniStr'
    => as 'Str';

coerce 'UniStr'
    => from 'Str'
    => via {
        my $v = $_;
        Encode::_utf8_on($v) unless Encode::is_utf8($v);
        return $v;
    };

coerce 'Str'
    => from 'UniStr'
    => via { $_ };

1;

=head1 NAME

Socialtext::MooseX::Types::UniStr - Moose type definitions for unicode strings

=head1 SYNOPSIS

  package MyPackage;
  use Moose;
  use Socialtext::MooseX::Types::UniStr;

  has 'when' => (
    is => 'rw', isa => 'UniStr', coerce => 1
  );

=head1 DESCRIPTION

C<Socialtext::MooseX::Types::UniStr> lets you make unicode string attributes.

=head1 TYPES / COERCIONS

=head2 UniStr

Coercions provided:

=over

=item from Str

Turns on the unicode bit unless C<Encode::is_utf8($_)> is already true for the string.

=item to Str

No-op; the unicode bit is left on.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
