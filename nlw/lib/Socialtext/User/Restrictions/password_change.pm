package Socialtext::User::Restrictions::password_change;

use Moose;
extends 'Socialtext::User::Restrictions::base';

# with some custom stuff

__PACKAGE__->meta->make_immutable;

1;
