package Socialtext::Rest::AccountPluginPrefs;
# @COPYRIGHT@
use Moose;
use Socialtext::AppConfig;
use Socialtext::HTTP ':codes';
use Socialtext::Pluggable::Plugin::Signals;
use Socialtext::JSON 'decode_json';
use Socialtext::Log 'st_log';
use List::MoreUtils 'all';
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Entity';

has 'account' => (
    is => 'ro', isa => 'Maybe[Socialtext::Account]',
    lazy_build => 1,
);
sub _build_account {
    my $self = shift;
    return Socialtext::Account->new(
        name => Socialtext::String::uri_unescape( $self->acct )
    );
}

sub PUT_json {
    my $self = shift;

    $self->can_admin(sub {
        my $rest    = $self->rest;
        my $signals = 'Socialtext::Pluggable::Plugin::Signals';
        my $acct    = $self->account;
        my $data    = eval { decode_json($self->rest->getContent()) };
        my %valid   = map { $_ => 1 } $signals->valid_account_prefs();

        if (!$data or ref($data) ne 'HASH') {
            $rest->header( -status => HTTP_400_Bad_Request );
            return 'Content should be a JSON hash.';
        }

        unless (all { defined $valid{$_} } keys %$data) {
            $rest->header( -status => HTTP_400_Bad_Request );
            return 'Unrecognized JSON key';
        }

        if (exists $data->{signals_size_limit}) {
            my $limit = $data->{signals_size_limit};

            if ($limit !~ /^\d+$/ || $limit <= 0) { # limit is a pos int
                $rest->header( -status => HTTP_400_Bad_Request );
                return "Size Limit must be a positive integer";
            }

            if ($limit > Socialtext::AppConfig->signals_size_limit) {
                $rest->header( -status => HTTP_403_Forbidden );
                return "Size Limit Exceeds Server Max";
            }
        }

        my $prefs = $signals->GetAccountPluginPrefTable($acct->account_id);
        $prefs->set(%$data);

        st_log()->info(
            $rest->user->username 
            . "changed signals preferences for " 
            . $acct->name
        );

        $rest->header(-status => HTTP_204_No_Content);
        return "";
    });
}

sub can_admin {
    my $self     = shift;
    my $callback = shift;
 
    return $self->no_resource('Account')
        unless $self->account && $self->account->is_plugin_enabled('signals');

    return $self->not_authorized()
        unless $self->rest->user->is_business_admin;

    return $callback->();
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor =>0);
1;
