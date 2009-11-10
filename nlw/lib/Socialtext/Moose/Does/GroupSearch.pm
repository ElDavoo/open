package Socialtext::Moose::Does::GroupSearch;

use Moose::Role;

requires 'Cursor';
requires 'SqlSelect';
requires 'SqlSortOrder';

sub ByGroupId {
    my $self_or_class = shift;
    my $group_id      = shift;
    my $closure       = shift;
    my %opts          = @_;

    $opts{order} = $self_or_class->SqlSortOrder()
        unless $opts{order};

    $opts{where}{group_id} = $group_id;

    my $sth = $self_or_class->SqlSelect(\%opts);
    return $self_or_class->Cursor($sth, $closure);
}

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::Does::GroupSearch - Moose Role for searching by Group

=head1 SYNOPSIS

  package MyClass;
  use Moose;
  with qw(
    Socialtext::CRUDFactory
    Socialtext::Moose::Does::GroupSearch
  );

  sub Cursor {
  }

=head1 DESCRIPTION

C<Socialtext::Moose::Does::GroupSearch> encapsulates methods used for
searching the underlying DB table by Groups.

=head1 METHODS

=over

=item B<$self_or_class-E<gt>ByGroupId($group_id, \&coderef)>

Searches the underlying DB table for records by Group Id, returning a
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
