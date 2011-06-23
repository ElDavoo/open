package Socialtext::Prefs::System;
use Moose;
use Try::Tiny;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::l10n qw(system_locale);
use Socialtext::Date::l10n;
use Socialtext::AppConfig;
use List::Util qw(first);

has 'prefs' => (is => 'rw', isa => 'HashRef', lazy_build => 1);
has 'config' => (is => 'ro', isa => 'Socialtext::AppConfig', 
    default => sub { Socialtext::AppConfig->instance() } );

sub _build_prefs {
    my $self = shift;
    my $config = $self->config;
    my $locale = $config->locale;

    return +{
        timezone => {
            timezone => $config->time_timezone || timezone($locale),
            dst => $config->time_dst || dst($locale),
            date_display_format => $config->time_date_display_format || date_display_format($locale),
            time_display_12_24 => $config->time_time_display_12_24 || time_display_12_24($locale),
            time_display_seconds => $config->time_time_display_seconds || time_display_seconds($locale),
        },
    };
}

sub all_prefs {
    my $self = shift;
    return $self->prefs;
}

sub save {
    my $self = shift;
    my $prefs = shift;

    die "timezone index required when saving system prefs\n"
        unless exists($prefs->{timezone});

    my $config = $self->config;
    my $timezone = $prefs->{timezone};

    my @fields = qw(timezone dst date_display_format
                    time_display_12_24 time_display_seconds);
    try {
        for my $ix (@fields) {
            my $value = $timezone->{$ix};
            my $setting = "time_$ix";
            $config->set($setting => $value);
        }
        $config->write();
    }
    catch { die "saving system prefs: $_\n" };

    return 1;
}

sub timezone { # XXX: stolen from ST::TimeZonePlugin
    my $loc = shift;
    return $loc eq 'ja' ? '+0900' : '-0800';
}

sub dst { # XXX: stolen from ST::TimeZonePlugin
    my $loc = shift;
    return $loc eq 'en' ? 'auto-us' : 'never';
}

sub time_display_seconds { return '0' }

sub date_display_format {
    my $loc = shift;
    my $default = Socialtext::Date::l10n->get_date_format($loc, 'default');
    my @formats = grep { $_ ne 'default' }
        Socialtext::Date::l10n->get_all_format_date($loc);

    return first {
        Socialtext::Date::l10n->get_date_format($loc, $_)->pattern
            eq $default->pattern;
    } @formats;
}

sub time_display_12_24 {
    my $loc = shift;
    my $default = Socialtext::Date::l10n->get_time_format($loc, 'default');
    my @formats = grep { $_ ne 'default' }
        Socialtext::Date::l10n->get_all_format_time($loc);

    return first {
        Socialtext::Date::l10n->get_time_format($loc, $_)->pattern
            eq $default->pattern;
    } @formats;
}

__PACKAGE__->meta->make_immutable();
1;

=head1 NAME

Socialtext::Prefs::System - An index of preferences for the System.

=head1 SYNOPSIS

    use Socialtext::Prefs::System

    my $acct_prefs = Socialtext::Prefs::System->new();

    $acct_prefs->prefs; # all prefs
    $acct_prefs->all_prefs; # alias of prefs()
    $acct_prefs->save({new_index=>{key1=>'value1',key2=>'value2'}});

=head1 DESCRIPTION

Manage System preferences.

=cut
