#!/usr/bin/perl
# @COPYRIGHT@

use strict;
use warnings;
use File::Slurp qw(write_file);
use mocked 'Apache::Request';
use Test::Socialtext tests => 2;
use Test::Differences;

fixtures(qw( base_config ));

use_ok 'Socialtext::Apache::Authen::NTLM';

###############################################################################
# Test data
my $NTLM_YAML =<<'EOY';
---
domain: SOCIALTEXT
primary: PRIMARY_DC
backup:
  - BACKUP_DC_ONE
  - BACKUP_DC_TWO
---
domain: EXAMPLE
primary: EX_PRIMARY_DC
backup:
  - EX_BACKUP_DC_ONE
  - EX_BACKUP_DC_TWO
EOY

###############################################################################
# The default configuration as set by Apache::AuthenNTLM
my %APACHE_AUTHEN_NTLM_DEFAULTS = (
    authbasic          => 1,
    authname           => '',
    authntlm           => 1,
    authtype           => 'ntlm,basic',
    basicauthoritative => 1,
    cacheuser          => '0',
    debug              => 0,
    ntlmauthoritative  => 1,
    semkey             => 23754,
    semtimeout         => 2,
    splitdomainprefix  => '',
    smbpdc             => { '' => undef },
    smbbdc             => { '' => undef },
);

###############################################################################
# TEST: load config
ntlm_load_config: {
    # Save our NTLM configuration
    my $cfg_file = Socialtext::NTLM::Config->config_filename();
    write_file($cfg_file, $NTLM_YAML);

    # create a mocked Apache::Request object to test with
    my $mock_request = Apache::Request->new();

    # create an Authen object, *just like* how its done in Apache::AuthenNTLM
    my $authen = bless +{}, 'Socialtext::Apache::Authen::NTLM';

    # Load up the config into the Authen handler
    $authen->get_config( $mock_request );

    # VERIFY: our NTLM config got loaded into the right places
    my %expected = (
        %APACHE_AUTHEN_NTLM_DEFAULTS,
        splitdomainprefix => 1,
        smbpdc            => {
            ''         => undef,             # set by Apache::AuthenNTLM
            socialtext => 'PRIMARY_DC',
            example    => 'EX_PRIMARY_DC',
        },
        smbbdc => {
            '' => undef,                     # set by Apache::AuthenNTLM
            socialtext => 'BACKUP_DC_ONE BACKUP_DC_TWO',
            example    => 'EX_BACKUP_DC_ONE EX_BACKUP_DC_TWO',
        },
        defaultdomain  => 'SOCIALTEXT',
        fallbackdomain => 'EXAMPLE',
    );

    my %actual = %{$authen};                # de-ref the object
    eq_or_diff \%actual, \%expected, 'NTLM config loaded correctly';

    # CLEANUP
    unlink $cfg_file;
}
