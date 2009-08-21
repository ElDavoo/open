package Socialtext::Moose::ObjectFactory;
# @COPYRIGHT@

use Moose::Role;
use namespace::clean -except => 'meta';

with qw(
    Socialtext::Moose::SqlBuilder
    Socialtext::Moose::SqlBuilder::Role::DoesSqlInsert
    Socialtext::Moose::SqlBuilder::Role::DoesSqlSelect
    Socialtext::Moose::SqlBuilder::Role::DoesSqlUpdate
    Socialtext::Moose::SqlBuilder::Role::DoesSqlDelete
    Socialtext::Moose::SqlBuilder::Role::DoesColumnFiltering
    Socialtext::Moose::SqlBuilder::Role::DoesTypeCoercion
);

no Moose::Role;
1;

=head1 NAME

Socialtext::Moose::ObjectFactory - ObjectFactory Role for SQL stored objects

=head1 SYNOPSIS

  package MyFactory;
  use Moose;
  with qw(
      Socialtext::Moose::ObjectFactory
  );
  ...

=head1 DESCRIPTION

C<Socialtext::Moose::ObjectFactory> provides a baseline Role for a Factory to
create objects that are stored in a SQL DB.

=head1 METHODS

=head1 AUTHOR

Socialtext, Inc.,  C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc.,  All Rights Reserved.

=cut
