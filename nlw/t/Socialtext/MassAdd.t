#!/usr/bin/perl
# @COPYRIGHT@
use strict;
use warnings;
use Test::More;

BEGIN {
    if (!-e 't/lib/Socialtext/People/Profile.pm') {
        plan skip_all => 'People is not linked in';
        exit;
    }
    
    plan tests => 75;
}

use mocked 'Socialtext::People::Profile', qw(save_ok);
use mocked 'Socialtext::Log', qw(:tests);
use mocked 'Socialtext::User';
$Socialtext::MassAdd::Has_People_Installed = 1;

use_ok 'Socialtext::MassAdd';

my %userinfo = (
    username      => 'ronnie',
    email_address => 'ronnie@mrshow.example.com',
    first_name    => 'Ronnie',
    last_name     => 'Dobbs',
    password      => 'brut4liz3',
    position      => 'Criminal',
    company       => 'FUZZ',
    location      => '',
    work_phone    => '',
    mobile_phone  => '',
    home_phone    => ''
);

Add_from_hash: {
    clear_log();
    $Socialtext::User::Users{ronnie} = undef;

    happy_path: {
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
        is_deeply \@failures, [], 'no failure messages';
        is delete $Socialtext::User::Confirmation_info{ronnie}, undef,
            'confirmation is not set';
        is delete $Socialtext::User::Sent_email{ronnie}, undef,
            'confirmation email not sent';
    }

    bad_profile_field: {
        no warnings 'redefine';
        local %Socialtext::People::Fields::InvalidFields = ( badfield => 1);
        local $userinfo{badfield} = 'badvalue';

        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is scalar(@failures), 1, "just one failure";
        like $failures[0], qr/Profile field "badfield" could not be updated/;
        logged_like 'error',
            qr/Profile field "badfield" could not be updated/,
            '... message also logged';

        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
    }
}

my $PIRATE_CSV = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
guybrush,guybrush@example.com,Guybrush,Threepwood,my_password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT

Add_one_user_csv: {
    # Explicitly set this user to undef, so we don't return a default mocked user
    $Socialtext::User::Users{guybrush} = undef;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($PIRATE_CSV);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    logged_like 'info', qr/Added user guybrush/, '... message also logged';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, undef,
        'confirmation is not set';
    is delete $Socialtext::User::Sent_email{guybrush}, undef,
        'confirmation email not sent';
}

Add_user_already_added: {
    local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
        username => 'guybrush',
    );

    uneditable_profile_field: {
        local @Socialtext::People::Fields::UneditableNames = qw/mobile_phone/;
        local $userinfo{mobile_phone} = '1-877-AVAST-YE';

        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->add_user(%userinfo);
        is scalar(@failures), 1, "just one failure";
        like $failures[0], qr/Profile field "mobile_phone" could not be updated/;
        logged_like 'error',
            qr/Profile field "mobile_phone" could not be updated/,
            '... message also logged';

        is_deeply \@successes, ['Added user ronnie'], 'success message ok';
        logged_like 'info', qr/Added user ronnie/, '... message also logged';
    }

    Profile_data_needs_update: {
        clear_log();
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        logged_like 'info', qr/Updated user guybrush/, '... message also logged';
        is_deeply \@failures, [], 'no failure messages';
    }

    Profile_data_already_up_to_date: {
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }

    Password_needs_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'elaine',
        );
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
        is $Socialtext::User::Users{guybrush}->password, 'my_password',
            'password was updated';
    }

    First_last_name_update: {
        local $Socialtext::User::Users{guybrush} = Socialtext::User->new(
            username => 'guybrush',
            password => 'my_password',
            first_name => 'Herman',
            last_name => 'Toothrot'
        );
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Captain',   company    => 'Pirates R. Us',
                location     => 'High Seas', work_phone => '123-456-YARR',
                mobile_phone => '',          home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';
        is $Socialtext::User::Users{guybrush}->first_name, 'Guybrush',
            'first_name was updated';
        is $Socialtext::User::Users{guybrush}->last_name, 'Threepwood',
            'last_name was updated';
    }

    Profile_update: {
        local $Socialtext::People::Profile::Profiles{1}
            = Socialtext::People::Profile->new(
                position     => 'Chef',          company    => 'Scumm Bar',
                location     => 'Monkey Island', work_phone => '123-456-YUCK',
                mobile_phone => '',              home_phone => '123-HIGH-SEA',
            );
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['Updated user guybrush'], 'success message ok';
        is_deeply \@failures, [], 'no failure messages';

        my $profile = $Socialtext::People::Profile::Profiles{1};
        is $profile->get_attr('position'), 'Captain', 'People position was updated';
        is $profile->get_attr('company'), 'Pirates R. Us', 'People company was updated';
        is $profile->get_attr('location'), 'High Seas', 'People location was updated';
        is $profile->get_attr('work_phone'), '123-456-YARR', 'People work_phone was updated';
    }

    Update_with_no_people_installed: {
        local $Socialtext::MassAdd::Has_People_Installed = 0;
        my @successes;
        my @failures;
        my $mass_add = Socialtext::MassAdd->new(
            pass_cb => sub { push @successes, shift },
            fail_cb => sub { push @failures,  shift },
        );
        $mass_add->from_csv($PIRATE_CSV);
        is_deeply \@successes, ['No changes for user guybrush'],
            'success message ok';
        is_deeply \@failures, [], 'no failure messages';
    }
}

Quoted_csv: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $quoted_csv = <<"EOT";
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
"lechuck","ghost\@lechuck.example.com","Ghost Pirate","LeChuck","my_password","Ghost","Ghost Pirates Inc","Netherworld","","",""
guybrush,guybrush\@example.com,Guybrush,Threepwood,my_password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($quoted_csv);
    is_deeply \@successes, ['Added user lechuck', 'Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
}

Contains_utf8: {
    local $Socialtext::User::Users{yamadat} = undef;
    my $utf8_csv = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
yamadat,yamadat@example.com,太郎,山田,パスワード太,社長,日本電気株式会社,location,+81 3 3333 4444,+81 70 1234 5678,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($utf8_csv);
    is_deeply \@successes, ['Added user yamadat'], 'success message ok, with utf8';
    is_deeply \@failures, [], 'no failure messages, with utf8';
}

Bad_email_address: {
    local $Socialtext::User::Users{lechuck} = undef;
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,example.com,Ghost Pirate,LeChuck,my_password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: example.com is not a valid email address'],
        'correct failure message';
    logged_like 'error',
        qr/\QLine 3: example.com is not a valid email address/,
        '... message also logged';
}

Duplicate_email_address: {
    # use a duplicate e-mail address (one already in use)
    (my $csv = $PIRATE_CSV) =~ s/guybrush@/duplicate@/;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, [], 'user was not added';
    is_deeply \@failures, ['Line 2: The email address you provided (duplicate@example.com) is already in use.'], 'correct failure message';
}

No_password: {
    # strip out the password from the csv line
    (my $csv = $PIRATE_CSV) =~ s/my_password//;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, 0,
        'confirmation is set';
    is delete $Socialtext::User::Sent_email{guybrush}, 1,
        'confirmation email sent';
}

Bad_password: {
    # Change the password to something too small
    (my $csv = $PIRATE_CSV) =~ s/my_password/pw/;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($csv);
    is_deeply \@successes, [], 'user was not added';
    is_deeply \@failures,
        ['Line 2: Passwords must be at least 6 characters long.'],
        'correct failure message';
    logged_like 'error', qr/Passwords must be at least 6 characters long/, '... message also logged';
}

Create_user_with_no_people_installed: {
    local $Socialtext::MassAdd::Has_People_Installed = 0;
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($PIRATE_CSV);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures, [], 'no failure messages';
    is delete $Socialtext::User::Confirmation_info{guybrush}, undef,
        'confirmation is not set';
    is delete $Socialtext::User::Sent_email{guybrush}, undef,
        'confirmation email not sent';
}

Missing_username: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
,ghost@lechuck.example.com,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: username is a required field, but it is not present.'],
        'correct failure message';
}

Missing_email: {
    my $bad_csv = $PIRATE_CSV . <<'EOT';
lechuck,,Ghost Pirate,LeChuck,password,Ghost,Ghost Pirates Inc,Netherworld,,,
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@successes, ['Added user guybrush'], 'success message ok';
    is_deeply \@failures,
        ['Line 3: email is a required field, but it is not present.'],
        'correct failure message';
}

Bogus_csv: {
    my $bad_csv = <<"EOT";
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
This line isn't CSV but we're going to try to parse/process it anyways
lechuck\tghost\@lechuck.example.com\tGhost Pirate\tLeChuck\tpassword\tGhost\tGhost Pirates Inc\tNetherworld\t\t\t
guybrush,guybrush\@example.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-YARR,,123-HIGH-SEA
EOT
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($bad_csv);
    is_deeply \@failures,
        ['Line 2: could not be parsed.  Skipping this user.',
         'Line 3: could not be parsed.  Skipping this user.',
        ],
        'correct failure message';
    is_deeply \@successes, ['Added user guybrush'], 'continued on to add next user';
}

Fields_for_account: {
    no warnings 'redefine', 'once';
    local *Socialtext::People::Fields::new = sub { "dummy" };
    my $acct = Socialtext::Account->Default;
    my $fields = Socialtext::MassAdd->ProfileFieldsForAccount($acct);
    is $fields, "dummy";
}

my $FLEET_CSV = <<'EOT';
username,email_address,first_name,last_name,password,position,company,location,work_phone,mobile_phone,home_phone
guybrush,guybrush@example.com,Guybrush,Threepwood,password,Captain,Pirates R. Us,High Seas,123-456-YARR,mobile1,123-HIGH-SEA
bluebeard,bluebeard@example.com,Blue,Beard,password,Captain,Pirates R. Us,High Seas,123-456-YARR,mobile2,123-HIGH-SEA
EOT

Add_multiple_users_faillure: {
    @Socialtext::People::Profile::Saved = ();
    local @Socialtext::People::Fields::UneditableNames = qw/mobile_phone/;

    # Explicitly set this user to undef, so we don't return a default mocked user
    $Socialtext::User::Users{guybrush} = undef;
    $Socialtext::User::Users{bluebeard} = undef;
    clear_log();
    my @successes;
    my @failures;
    my $mass_add = Socialtext::MassAdd->new(
        pass_cb => sub { push @successes, shift },
        fail_cb => sub { push @failures,  shift },
    );
    $mass_add->from_csv($FLEET_CSV);
    is_deeply \@successes, ['Added user guybrush','Added user bluebeard'], 'success message ok';
    logged_like 'info', qr/Added user guybrush/, '... message also logged';
    logged_like 'info', qr/Added user bluebeard/, '... message also logged';
    is scalar(@failures), 1, 'only one error message per field updating failure';
    like $failures[0],
        qr/Profile field "mobile_phone" could not be updated/,

    my $profile1 = shift @Socialtext::People::Profile::Saved;
    isnt $profile1->{mobile_phone}, 'mobile1';
    my $profile2 = shift @Socialtext::People::Profile::Saved;
    isnt $profile2->{mobile_phone}, 'mobile2';
}
