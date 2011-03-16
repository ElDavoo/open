# @COPYRIGHT@
package Socialtext::EmailNotifyPlugin;
use strict;
use warnings;
use base 'Socialtext::Plugin';
use Class::Field qw( const field );
use Socialtext::EmailNotifier;
use Socialtext::l10n qw( loc loc_lang system_locale );

const class_id => 'email_notify';
const class_title => _('class.email_notify');
field abstracts => [];
field 'lock_handle';
field notify_requested => 0;

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(preference => $self->notify_frequency);
    $registry->add(preference => $self->sort_order);
    $registry->add(preference => $self->links_only);
}

our $Default_notify_frequency = 1440;

sub notify_frequency {
    my $self = shift;
    my $p = $self->new_preference('notify_frequency');
    $p->query(loc('email.frequency?'));
    $p->type('pulldown');
    my $choices = [
        0 => loc('time.never'),
        1 => loc('every.minute'),
        5 => loc('every.5minutes'),
        15 => loc('every.15minutes'),
        60 => loc('every.hour'),
        360 => loc('every.6hours'),
        1440 => loc('every.day'),
        4320 => loc('every.3days'),
        10080 => loc('every.week'),
    ];
    $p->choices($choices);
    $p->default($Default_notify_frequency);
    return $p;
}

sub sort_order {
    my $self = shift;
    my $p = $self->new_preference('sort_order');
    $p->query(loc('email.page-digest-sort?'));
    $p->type('radio');
    my $choices = [
        chrono => loc('sort.oldest-first'),
        reverse => loc('sort.newest-first'),
        name => loc('sort.page-name'),
    ];
    $p->choices($choices);
    $p->default('chrono');
    return $p;
}

sub links_only {
    my $self = shift;
    my $p = $self->new_preference('links_only');
    $p->query(loc('email.page-digest-details?'));
    $p->type('radio');
    my $choices = [
        condensed => loc('email.page-name-link-only'),
        expanded => loc('email.page-name-link-author-date'),
    ];
    $p->choices($choices);
    $p->default('expanded');
    return $p;
}

1;

