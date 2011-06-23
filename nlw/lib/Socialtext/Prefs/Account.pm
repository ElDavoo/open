package Socialtext::Prefs::Account;
use Moose;
use Try::Tiny;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::Prefs::System;

has 'account' => (is => 'ro', isa => 'Socialtext::Account', required => 1);
has 'prefs' => (is => 'ro', isa => 'HashRef',
                lazy_build => 1, clearer => '_clear_prefs');
has 'all_prefs' => (is => 'ro', isa => 'HashRef',
                    lazy_build => 1, clearer =>'_clear_all_prefs');

sub _build_prefs {
    my $self = shift;

    my $blob = $self->account->pref_blob;
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
    my $system_prefs = Socialtext::Prefs::System->new()->all_prefs;
    my $acct_prefs = $self->prefs;

    return +{%$system_prefs, %$acct_prefs};
}

sub save {
    my $self = shift;
    my $updates = shift;
    my $current = $self->prefs;

    my %prefs = clear_undef_indexes(%$current, %$updates);

    try {
        my $blob = eval { encode_json(\%prefs) };
        sql_execute(
            'UPDATE "Account" SET pref_blob = ? WHERE account_id = ?',
            $blob, $self->account->account_id
        );
        $self->update_objects($blob);
    }
    catch { die "saving account prefs: $_\n" };

    return 1;
}

sub update_objects {
    my $self = shift;
    my $blob = shift;

    $self->account->pref_blob($blob);
    $self->_clear_all_prefs;
    $self->_clear_prefs;
}

sub clear_undef_indexes {
    my %prefs = @_;

    return map { $_ => $prefs{$_} }
        grep { $prefs{$_} } keys %prefs;
}

__PACKAGE__->meta->make_immutable();
1;

=head1 NAME

Socialtext::Prefs::Account - An index of preferences for an Account.

=head1 SYNOPSIS

    use Socialtext::Prefs::Account

    my $acct_prefs = Socialtext::Prefs::Account->new(account=>$account);

    $acct_prefs->prefs; # all prefs
    $acct_prefs->all_prefs; # all prefs, including inherited system prefs
    $acct_prefs->save({new_index=>{key1=>'value1',key2=>'value2'}});

=head1 DESCRIPTION

Manage the preferences for an Account.

=cut
