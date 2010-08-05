package Socialtext::Rest::OpenToken::Factory;
# @COPYRIGHT@

use Moose;
use DateTime;
use Crypt::OpenToken;
use POSIX qw(strftime);
use Socialtext::HTTP qw(:codes);

extends 'Socialtext::Rest';
with 'Socialtext::Rest::OpenToken';

sub allowed_methods { 'GET' };

sub login {
    my $self = shift;
    my $rest = shift;
    my $user = $rest->user;

    # You better be authenticated (somehow) if you want to create a token.
    unless ($user->is_authenticated && !$user->is_deleted) {
        $rest->header(-status => HTTP_401_Unauthorized);
        return '';
    }

    # Extract inbound params
    #   username    - Username to create token for (default; logged in user)
    #   ttl         - TTL for token (relative to "now")
    my $username = $rest->query->param('username') || $user->username;
    my $ttl      = $rest->query->param('ttl')      || $self->default_ttl;

    my %params = (
        'subject'         => $username,
        'not-before'      => _make_iso8601_date(time),
        'not-on-or-after' => _make_iso8601_date(time+$ttl),
    );

    # Business Admins can request tokens for other Users.
    if ($username ne $user->username) {
        unless ($user->is_business_admin) {
            return $self->not_authorized();
        }
        $params{'created-by'} = $user->username;
    }

    # Create the token
    my $token = $self->factory->create(
        Crypt::OpenToken::CIPHER_AES128,
        \%params,
    );
    return $token;
}

sub default_ttl {
    return 86400;   # 24h
}

sub _make_iso8601_date {
    my $time_t = shift;
    return strftime('%Y-%m-%dT%H:%M:%SGMT', gmtime($time_t));
}

1;
