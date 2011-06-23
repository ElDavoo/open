package Socialtext::Prefs::User;
use Moose;
use Try::Tiny;
use Socialtext::JSON qw(encode_json decode_json);
use Socialtext::SQL qw(sql_singlevalue sql_execute sql_txn);
use Socialtext::Prefs::Account;

has 'user' => (is => 'ro', isa => 'Socialtext::User', required => 1);
has 'prefs' => (is => 'ro', isa => 'HashRef',
                lazy_build => 1, clearer => '_clear_prefs');
has 'all_prefs' => (is => 'ro', isa => 'HashRef',
                    lazy_build => 1, clearer =>'_clear_all_prefs');

sub _build_prefs {
    my $self = shift;

    my $blob = sql_singlevalue(qq{
        SELECT pref_blob
          FROM user_pref
         WHERE user_id = ?
    }, $self->user->user_id);
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
    my $user = $self->user;
    my $acct_prefs = $user->primary_account->prefs->all_prefs;
    my $user_prefs = $self->prefs;

    return +{%$acct_prefs, %$user_prefs};
}

sub save {
    my $self = shift;
    my $updates = shift;
    my $current = $self->prefs;

    my $user_id = $self->user->user_id;
    my %prefs = clear_undef_indexes(%$current,%$updates);
    my $has_prefs = keys %prefs ? 1 : 0;
    try {
        sql_txn {
            sql_execute(
                'DELETE FROM user_pref WHERE user_id = ?',
                $user_id
            );

            if ($has_prefs) {
                my $blob = eval { encode_json(\%prefs) };
                sql_execute(
                    'INSERT INTO user_pref (user_id,pref_blob) VALUES (?,?)',
                    $user_id, $blob
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

__PACKAGE__->meta->make_immutable();
1;

=head1 NAME

Socialtext::Prefs::User - An index of preferences for a User.

=head1 SYNOPSIS

    use Socialtext::Prefs::User

    my $user_prefs = Socialtext::Prefs::User->new(user=>$user);

    $user_prefs->prefs; # all prefs
    $user_prefs->all_prefs; # all prefs, including inherited account prefs
    $user_prefs->save({new_index=>{key1=>'value1',key2=>'value2'}});

=head1 DESCRIPTION

Manage the preferences for a User.

=cut
