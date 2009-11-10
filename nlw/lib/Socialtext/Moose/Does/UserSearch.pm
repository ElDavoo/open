package Socialtext::Moose::Does::UserSearch;

use Moose::Role;

requires 'Cursor';
requires 'SqlSelect';
requires 'SqlSortOrder';

sub ByUserId {
    my $self_or_class = shift;
    my $user_id       = shift;
    my $closure       = shift;
    my $order         = $self_or_class->SqlSortOrder();

    my $sth = $self_or_class->SqlSelect( {
        where => { user_id => $user_id },
        order => $order,
    } );
    return $self_or_class->Cursor($sth, $closure);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::Does::UserSearch - Moose Role for searching by User

=head1 SYNOPSIS

  package MyClass;
  use Moose;
  with qw(
    Socialtext::CRUDFactory
    Socialtext::Moose::Does::UserSearch
  );

  sub Cursor {
  }

=head1 DESCRIPTION

C<Socialtext::Moose::Does::UserSearch> encapsulates methods used for searching
the underlying DB table by Users.

=head1 METHODS

=over

=item B<$self_or_class-E<gt>ByUserId($user_id, \&coderef)>

Searches the underlying DB table for records by User Id, returning a
C<Socialtext::MultiCursor> containing objects for each of the result records.

An optional C<\&coderef> can be passed through, which can be used to
manipulate the result object before it gets handed back by
C<Socialtext::MultiCursor-E<gt>next()>.

=back

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
