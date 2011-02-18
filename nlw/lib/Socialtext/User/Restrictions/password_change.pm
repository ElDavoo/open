package Socialtext::User::Restrictions::password_change;

use Moose;
with 'Socialtext::User::Restrictions::base';

sub restriction_type { 'password_change' };

# with some custom stuff

__PACKAGE__->meta->make_immutable;

1;
