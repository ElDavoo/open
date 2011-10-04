#!perl
# @COPYRIGHT@

use strict;
use warnings;
use DateTime;
use Socialtext::Pages;
use Test::Socialtext tests => 6;

fixtures(qw(db));
use_ok 'Socialtext::WorkspaceListPlugin';

1;
