package Socialtext::User::Restrictions::email_confirmation;

use Moose;
with 'Socialtext::User::Restrictions::base';

sub restriction_type { 'email_confirmation' };

# with some custom stuff

__PACKAGE__->meta->make_immutable;

1;
