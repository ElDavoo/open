# @COPYRIGHT@
package Socialtext::Rest::Config;
use strict;
use warnings;
no warnings 'once';

use base 'Socialtext::Rest';
use YAML ();
use Socialtext::HTTP ':codes';
use Socialtext::Rest::Version;
use Socialtext::JSON;
use Socialtext;
use Socialtext::AppConfig;
use Readonly;

Readonly my @PUBLIC_CONFIG_KEYS => qw(
    allow_network_invitation
);

sub allowed_methods { 'GET' }

sub make_getter {
    my ( $type, $render ) = @_;
    return sub {
        my ( $self, $rest ) = @_;

        my $user = $rest->user;

        unless ($user->is_authenticated and !$user->is_deleted) {
            $rest->header(-status => HTTP_401_Unauthorized);
            return '';
        }


        $rest->header(type => "$type; charset=UTF-8");

        local $YAML::UseHeader = 0; # Get simple key/value pair without the "---" line
        return $render->({
            server_version => $Socialtext::VERSION,
            api_version => $Socialtext::Rest::Version::API_VERSION,
            ( map { $_ => Socialtext::AppConfig->$_() } @PUBLIC_CONFIG_KEYS ),
        });

    };
}

*GET_text = make_getter( 'text/plain', \&YAML::Dump );
*GET_json = make_getter( 'application/json', \&encode_json );

1;
