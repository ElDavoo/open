package Socialtext::Gadgets::Container::Dashboard;
# @COPYRIGHT@
use Moose;
use Socialtext::Gadgets::Container::AccountDashboard;
use namespace::clean -except => 'meta';

use constant 'type'            => 'dashboard';
use constant 'links_template'  => 'dashboard_links';
use constant 'hello_template'  => 'dashboard_hello';
use constant 'footer_template' => '';
use constant 'global'          => 0;
use constant 'title'           => "Socialtext Dashboard";
use constant 'plugin'          => "dashboard";
use constant 'search'          => 'signals';

with 'Socialtext::Gadgets::Container',
     'Socialtext::Gadgets::Container::BaseDashboard';

has '+owner' => (isa => 'Socialtext::User');

sub JoinSQL {
    return q{
        LEFT JOIN (
            SELECT user_id, user_id AS user_set_id FROM users
        ) u USING(user_set_id)
    };
}

sub _build_env {
    my $self = shift;
    return {
        owner              => $self->owner->username,
        owner_id           => $self->owner->user_id,
        owner_name         => $self->owner->guess_real_name,
        primary_account    => $self->owner->primary_account->name,
        primary_account_id => $self->owner->primary_account_id,
    };
}

__PACKAGE__->meta->make_immutable;
1;
