package Socialtext::Challenger::Base;
# @COPYRIGHT@

use strict;
use warnings;

1;

=head1 NAME

Socialtext::Challenger::Base - Base class for Authen Challengers

=head1 SYNOPSIS

  # derive your own challenger
  package Socialtext::Challenger::MyChallenger;

  use base qw(Socialtext::Challenger::Base);

  sub challenge {
  # ...
  }

  1;

=head1 DESCRIPTION

This module provides a base class for Authen Challengers, making several
helper methods available for use across Challengers.

=head1 METHODS

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Socialtext, Inc., All Rights Reserved.

=cut
