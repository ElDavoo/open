package Socialtext::User::Restrictions::email_confirmation;

use Moose;
extends 'Socialtext::User::Restrictions::base';

# with some custom stuff

__PACKAGE__->meta->make_immutable;

1;
