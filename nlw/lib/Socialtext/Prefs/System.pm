package Socialtext::Prefs::System;
use Moose;
use Try::Tiny;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::l10n qw(system_locale);
use Socialtext::Date::l10n;
use Socialtext::AppConfig;
use List::Util qw(first);

has 'prefs' => (is => 'ro', isa => 'HashRef',
                lazy_build => 1, clearer => '_clear_prefs');
has 'all_prefs' => (is => 'ro', isa => 'HashRef',
                    lazy_build => 1, clearer =>'_clear_all_prefs');

sub _build_prefs {
    my $blob = sql_singlevalue(qq{
        SELECT value
          FROM "System"
         WHERE field = 'pref_blob'
    });
    return {} unless $blob;

    my $prefs = eval { decode_json($blob) };
    if (my $e = $@) { 
        st_log->error("failed to load prefs blob: $e");
        return {};
    }
 
    return $prefs;
}

sub _build_all_prefs {
    my $self = shift;
    my $sys_prefs = $self->prefs;
    my $locale = Socialtext::AppConfig->locale;

    my $defaults = +{
        timezone => {
            timezone => timezone($locale),
            dst => dst($locale),
            date_display_format => date_display_format($locale),
            time_display_12_24 => time_display_12_24($locale),
            time_display_seconds => time_display_seconds($locale),
        },
    };

    return +{%$defaults, %$sys_prefs};
}

sub save {
    my $self = shift;
    my $updates = shift;
    my $sys_prefs = $self->prefs;

    my %prefs = clear_undef_indexes(%$sys_prefs, %$updates);
    my $has_prefs = keys %prefs ? 1 : 0;
    try {
        sql_txn {
            sql_execute('DELETE FROM "System" WHERE field = ?', 'pref_blob');

            if ($has_prefs) {
                my $blob = eval { encode_json(\%prefs) };
                sql_execute(
                    'INSERT INTO "System" (field,value) VALUES (?,?)',
                    'pref_blob', $blob
                );
            }
        };
        $self->update_objects;
    }
    catch { die "saving user prefs: $_\n" };

    return 1;
}

sub update_objects {
    my $self = shift;
    my $blob = shift;

    $self->_clear_all_prefs;
    $self->_clear_prefs;
}

sub clear_undef_indexes {
    my %prefs = @_;

    return map { $_ => $prefs{$_} }
        grep { $prefs{$_} } keys %prefs;
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
