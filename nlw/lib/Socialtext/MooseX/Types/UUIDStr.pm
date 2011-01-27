package Socialtext::MooseX::Types::UUIDStr;
use warnings;
use strict;
use Moose::Util::TypeConstraints;

subtype 'Str.UUID'
    => as 'Str'
    # e.g. dfd6fd31-e518-41ca-ad5a-6e06bc46f1dd
    => where { /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i }
    => message { "invalid UUID" };

no Moose::Util::TypeConstraints;
1;
