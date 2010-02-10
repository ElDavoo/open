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


        $rest->header(-type => "$type; charset=UTF-8");

        # Get simple key/value pair without the "---" line
        local $YAML::UseHeader = 0;

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
__END__

=head1 NAME

Socialtext::Rest::Config

=head1 SYNOPSIS

  GET /data/config

=head1 DESCRIPTION

Retrieves "public" config information from various parts of the application.

Supports C<text/plain> (which is actually YAML without the --- header) and
C<application/json> representations.

=cut
