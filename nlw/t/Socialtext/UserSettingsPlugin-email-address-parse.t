#!perl
# @COPYRIGHT@
use strict;
use warnings;

use Test::Socialtext tests => 8;
use Socialtext::UserSettingsPlugin;
use Socialtext::Helpers;

delimiters '===', '>>>';
run {
    my $case = shift;
    my ($got) = Socialtext::Helpers->validate_email_addresses($case->mail);
    if ($got->[0]) {
        $got = [ $got->[0]{email_address}, $got->[0]->{first_name}, $got->[0]{last_name} ];
    }
    my $expected = YAML::Load($case->expected);
    is YAML::Dump($got), YAML::Dump($expected), $case->mail;
};

{
    my $input = <<'EOT';
rking@panoptic.com,
<rking@sharpsaw.org>,rking-afraidofspam@sharpsaw.org,
"Ze Burro" <burro@panoptic.com>, Devin Nullington <devnull9@socialtext.com>
mailto:devnull2@socialtext.com
EOT
    my @actual = Socialtext::Helpers->_split_email_addresses($input);

    my @expected = ( 'rking@panoptic.com',
                     '<rking@sharpsaw.org>',
                     'rking-afraidofspam@sharpsaw.org',
                     q|"Ze Burro" <burro@panoptic.com>|,
                     'Devin Nullington <devnull9@socialtext.com>',
                     'mailto:devnull2@socialtext.com',
                   );
    is_deeply( \@actual, \@expected, 'split_emails_from_blob_of_text' );
}
__DATA__
===
>>> mail: rking@panoptic.com
>>> expected
- rking@panoptic.com
- rking
- ~

===
>>> mail: "Ryan King" <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- Ryan
- King

===
>>> mail: Ryan King <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- Ryan
- King

===
>>> mail: mailto:rking@panoptic.com
>>> expected
- rking@panoptic.com
- rking
- ~

===
>>> mail: <rking@panoptic.com>
>>> expected
- rking@panoptic.com
- rking
- ~

=== (Blank line)
>>> mail:
>>> expected
--- []

=== (Nulls)
>>> mail: rking @pan ptic.com
>>> expected
--- []
