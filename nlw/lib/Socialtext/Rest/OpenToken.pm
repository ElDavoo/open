package Socialtext::Rest::OpenToken;
# @COPYRIGHT@

use Moose::Role;
use Crypt::OpenToken;
use MIME::Base64 qw(decode_base64);
use Socialtext::OpenToken::Config;

has 'config' => (
    is         => 'ro',
    isa        => 'Socialtext::OpenToken::Config',
    lazy_build => 1,
);
sub _build_config {
    my $config = Socialtext::OpenToken::Config->load();
    unless ($config) {
        die "OpenToken configuration missing/invalid.\n";
    }
    return $config;
}

has 'factory' => (
    is         => 'ro',
    isa        => 'Crypt::OpenToken',
    lazy_build => 1,
);
sub _build_factory {
    my $self     = shift;
    my $config   = $self->config();
    my $password = decode_base64($config->password);
    return Crypt::OpenToken->new(password => $password);
}

1;
