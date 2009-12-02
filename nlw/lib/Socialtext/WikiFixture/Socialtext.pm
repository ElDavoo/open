# @COPYRIGHT@
package Socialtext::WikiFixture::Socialtext;
use strict;
use warnings;
use base 'Socialtext::WikiFixture::SocialBase';
use base 'Socialtext::WikiFixture::Selenese';
use Socialtext::Cache;
use Socialtext::System qw/shell_run/;
use Socialtext::Workspace;
use Sys::Hostname;
use Test::More;
use Test::Socialtext;
use Test::Output qw(combined_from);
use Text::ParseWords qw(shellwords);
use Cwd;
use Socialtext::AppConfig;

=head1 NAME

Socialtext::WikiFixture::Selenese - Executes wiki tables using Selenium RC

=cut

our $VERSION = '0.03';

=head1 DESCRIPTION

This module is a subclass of Socialtext::WikiFixture::Selenese and includes
extra commands specific for testing a Socialtext wiki.

=head1 FUNCTIONS

=head2 new( %opts )

Create a new fixture object.  The same options as
Socialtext::WikiFixture::Selenese are required, as well as:

=over 4

=item workspace

Mandatory - Specifies which Socialtext workspace will be tested.

=item username

Mandatory - username to login to the wiki with.

=item password

Mandatory - password to login to the wiki with.

=back

=head2 init()

Creates the Test::WWW::Selenium object, and logs into the Socialtext
workspace.

=cut

sub init {
    my ($self) = @_;

    $self->{mandatory_args} ||= [qw(workspace username password)];
    for (@{ $self->{mandatory_args} }) {
        die "$_ is mandatory!" unless $self->{$_};
    }
   
    #Get the workspace skin if the workspace attribute is set
    #Otherwise, default to s3
    my $ws = Socialtext::Workspace->new( name => $self->{workspace} );
    my $skin = 's3';
    if (defined($ws)) {
        $skin = $ws->skin_name() || 's3';
        $self->{'workspace_id'} = $ws->workspace_id;
    }
  
    $self->{'skin'} = $skin;
    
    my $short_username = $self->{'username'};
    $short_username =~ s/^([\W\w\.]*)\@.+$/$1/; # truncate if email address
    $self->{'short_username'} = $short_username || $self->{'username'};
    
    $self->SUPER::init;
    Socialtext::WikiFixture::Selenese::init($self); # how to do this better?

    { # Talc/Topaz are configured to allow emailing into specific dev-envs
        (my $host = $self->{browser_url}) =~ s#^http.?://(.+):\d+#$1#;
        $self->{wikiemail} = $ENV{WIKIEMAIL} || "$ENV{USER}.$host";
        diag  "wikiemail:  $self->{wikiemail}";
    }
    diag "Browser url is ".$self->{browser_url};
    $self->st_login;
}

=head2 handle_command( @row )

Run the command.  Subclasses can override this.

=cut

sub handle_command {
    my $self = shift;
    
    # Try the SocialBase commands first
    my @args = $self->_munge_command_and_opts(@_);
    eval { $self->SUPER::_handle_command(@args) };
    return unless $@;

    # Fallback to Selenese command processing
    $self->SUPER::handle_command(@_);
}


=head2 todo()

Same as a comment, but acts as a failing TODO test.

Useful for leaving a trail of breadcrumbs for yourself for things that you
haven't gotten to yet, but that you plan on implementing.

Outputs standard TAP for a failed TODO test.

=cut

{
    no warnings 'redefine';
    sub todo {
        my $self = shift;
        my $msg  = shift;
        TODO: {
            local $TODO = 'not yet implemented';
            ok 0, $msg;
        }
    }
}

=head2 st_login()

Logs into the Socialtext wiki using supplied username and password.

=cut

sub st_login {
    my $self = shift;
    my $sel = $self->{selenium};

    my $username = shift || $self->{username};
    my $password = shift || $self->{password};
    my $workspace = shift || $self->{workspace};

    my $url = '/nlw/login.html';
    $url .= "?redirect_to=\%2F$workspace\%2Findex.cgi" if $workspace;
    diag "st-login: $username, $password, $workspace - $url";
    $sel->open_ok($url);
    $sel->type_ok('username', $username);
    $sel->type_ok('password', $password);
    $self->click_and_wait(q{id=login_btn}, 'log in');
}

=head2 st_logout()

Log out of the Socialtext wiki.

=cut

sub st_logout {
    my $self = shift;
    diag "st-logout";
    $self->click_and_wait('id=logout_btn', 'log out');
}

=head2 st_logoutin()

Logs out of the workspace, then logs back in.

A username and password are optional parameters, and will be used in place
of the configured username and password.

=cut

sub st_logoutin {
    my ($self, $username, $password) = @_;
    $self->st_logout;
    $self->st_login($username, $password);
}

=head2 st_page_title( $expected_title )

Verifies that the page title (NOT HTML title) is correct.

=cut

sub st_page_title {
    my ($self, $expected_title) = @_;
    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-list-title', qr/\Q$expected_title\E/);
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', qr/\Q$expected_title\E/);
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
}

=head2 st_page_multi_view( $url, $numviews) 

Looks at the page default_server/url numviews number of times. 

Useful to canning up page views for reports, metrics widgets, etc.

=cut

sub st_page_multi_view {
  my ($self, $url, $numviews) = @_;
  for (my $idx=0; $idx<$numviews;$idx++) {
      $self->{selenium}->open_ok($url);
      $self->handle_command('wait_for_element_visible_ok','link=Edit','30000');
  }
}

=head2 st_page_multi_watch( $numwatches) 

Watch-On, Watch-Off, repeat.  Useful for metrics on pages, user activities, etc

=cut

sub st_page_multi_watch {
  my ($self, $numwatches) = @_;
  for (my $idx=0; $idx<$numwatches;$idx++) {
     $self->st_watch_page(1);
     $self->st_is_watched(1);
     $self->st_watch_page(0);
     $self->st_is_watched(0);
  }
}

=head2 st_page_create ( $workspace, pagename )

Creates a plain-english page at server/workspace/pagname and leaves you in view mode.  

So if you pass in page name of "Super Matt", it will save as "Super Matt" and have
a url of super_matt

This is done through the GUI. (You may want to do this through the GUI if, say, you 
want the output written to nlw.log)

=cut

sub st_create_wikipage {
    my ($self, $workspace, $pagename)  = @_;
    my $url = '/' . $workspace . '/?action=display;page_type=wiki;page_name=Untitled Page#edit';
    $self->{selenium}->open_ok($url);
    $self->handle_command('wait_for_element_visible_ok','link=Wiki Text',30000);
    $self->handle_command('click_ok','link=Wiki Text');
    $self->handle_command('wait_for_element_visible_ok','wikiwyg_wikitext_textarea',30000);
    $self->handle_command('wait_for_element_visible_ok','st-newpage-pagename-edit',30000);
    $self->handle_command('type_ok','st-newpage-pagename-edit',$pagename);
    $self->handle_command('wait_for_element_visible_ok','st-save-button-link',30000);
    $self->handle_command('click_ok','st-save-button-link');
    $self->handle_command('wait_for_element_visible_ok','st-edit-button-link',30000);                
}

=head2 st_add_page_tag ( $url, $page, $tag) 

Adds a tag to a wikipage through the GUI.

First goes to server/$url (url should include workspace)

The page must exist in order to have a tag added.

=cut

sub st_add_page_tag {
   my ($self, $url, $tag) = @_;
   $self->handle_command('open_ok',$url);
   $self->handle_command('wait_for_element_visible_ok','st-pagetools-email', 30000);
   $self->handle_command('wait_for_element_visible_ok','link=Add Tag',30000);
   $self->handle_command('wait_for_element_visible_ok','st-edit-button-link-bottom',30000);
   $self->handle_command('wait_for_element_visible_ok','st-comment-button-link-bottom',30000);
   $self->handle_command('pause', 3000);
   $self->handle_command('click_ok','link=Add Tag'); 
   $self->handle_command('wait_for_element_visible_ok','st-tags-field',30000);
   $self->handle_command('type_ok', 'st-tags-field', $tag);
   $self->handle_command('wait_for_element_visible_ok', 'st-tags-plusbutton-link', 30000);
   $self->handle_command('click_ok','st-tags-plusbutton-link');
   $self->handle_command('wait_for_element_visible_ok','link='.$tag, 30000);
}


=head2 st_comment_on_page ($workspace, $url, $comment)

Opens up a specific page via $url, which should be of the form:

/workspace/?page OR /workspace/index.cgi?page

clicks the comment button and leaves your note.

=cut

sub st_comment_on_page {
    my ($self, $url, $comment) = @_;
    $self->handle_command('open_ok', $url);  
    $self->handle_command('wait_for_element_visible_ok','st-comment-button-link', 30000);
    $self->handle_command('click_ok','st-comment-button-link');
    $self->handle_command('wait_for_element_visible_ok','comment',30000);
    $self->handle_command('type_ok', 'comment', $comment);
    $self->handle_command('wait_for_element_visible_ok','link=Save',30000);
    $self->handle_command('click_ok','link=Save');
    $self->handle_command('wait_for_element_visible_ok','st-comment-button-link', 30000);
}

=head2 st_edit_page ($workspace, $page, $text)

Opens up a specific page via $url, which should be of the form:

/workspace?page or /workspace/index.cgi?page

Then edits it and types the text you suggest

=cut

sub st_edit_page {
  my ($self, $url, $text) = @_;
  $self->handle_command('open_ok',  $url); 
  $self->handle_command('wait_for_element_visible_ok', 'st-edit-button-link', 30000);  
  $self->handle_command('click_ok','st-edit-button-link');
  $self->handle_command('wait_for_element_visible_ok', 'link=Wiki Text',  30000);
  $self->handle_command('click_ok','link=Wiki Text');
  $self->handle_command('wait_for_element_visible_ok','wikiwyg_wikitext_textarea',30000);
  $self->handle_command('type_ok','wikiwyg_wikitext_textarea', $text);
  $self->handle_command('wait_for_element_visible_ok','st-save-button-link',30000);
  $self->handle_command('click_and_wait','st-save-button-link');
   $self->handle_command('wait_for_element_visible_ok', 'st-edit-button-link', 30000); 
}


=head2 st_email_page ($self, $url, $email_address) 

Emails a page

=cut

sub st_email_page {
    my ($self, $url, $email) = @_;
    $self->handle_command('open_ok',$url);
    $self->handle_command('wait_for_element_visible_ok','st-pagetools-email', 30000);
    $self->handle_command('pause', 2000);
    $self->handle_command('click_ok','st-pagetools-email');
    $self->handle_command('wait_for_element_visible_ok','st-email-lightbox', 30000);
    $self->handle_command('wait_for_element_visible_ok','email_recipient', 30000);
    $self->handle_command('type_ok', 'email_recipient', $email);
    $self->handle_command('wait_for_element_visible_ok','email_add', 30000);
    $self->handle_command('click_ok', 'email_add');
    $self->handle_command('text_like', 'email_page_user_choices', $email);
    $self->handle_command('wait_for_element_visible_ok','email_send', 30000);
    $self->handle_command('click_ok', 'email_send');
    $self->handle_command('wait_for_element_not_visible_ok', 'st-email-lightbox',30000);
}

=head2 st_search( $search_term, $expected_result_title )

Performs a search, and then validates the result page has the correct title.

=cut


sub st_search {
    my ($self, $opt1, $opt2) = @_;
    my $sel = $self->{selenium};
 
    $sel->type_ok('st-search-term', $opt1);
    
    if ($self->{'skin'} eq 's2') {
        $sel->click_ok('link=Search');
    } elsif ($self->{'skin'} eq 's3') {
        $sel->click_ok('st-search-submit');
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
    
    $sel->wait_for_page_to_load_ok($self->{selenium_timeout});
    
    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-list-title', qr/\Q$opt2\E/);
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', qr/\Q$opt2\E/);
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }
}

=head2 st_result( $expected_result )

Validates that the search result content contains a correct result.

=cut

sub st_result {
    my ($self, $opt1, $opt2) = @_;

    if ($self->{'skin'} eq 's2') {
        $self->{selenium}->text_like('id=st-search-content', 
                                 $self->quote_as_regex($opt1));
    } elsif ($self->{'skin'} eq 's3') {
        $self->{selenium}->text_like('//div[@id=\'contentContainer\']', $self->quote_as_regex($opt1));
    } else {
        ok 0, "Unknown skin type: $self->{'skin'}";
    }

}

=head2 st_submit()

Submits the current form

=cut

sub st_submit {
    my ($self) = @_;

    $self->click_and_wait(q{//input[@value='Submit']}, 'click submit button');
}

=head2 st_message()

Verifies an error or message appears.

=cut

sub st_message {
    my ($self, $message) = @_;

    $self->text_like(q{errors-and-messages},
                     $self->quote_as_regex($message));
}



=head2 st_watch_page( $watch_on, $page_name, $verify_only )

Adds/removes a page to the watchlist.

If the first argument is true, the page will be added to the watchlist.
If the first argument is false, it will be removed from the watchlist.

If the second argument is not specified, it is assumed that the browser
is already open to a wiki page, and the opened page should be watched.

If the second argument is supplied, it is assumed that the browser
is on the watchlist page, and only the given page name should be watched.

If the 3rd argument is true, only checks will be performed as to whether
the specified page is watched or not.

=cut

sub st_watch_page {
    my ($self, $watch_on, $page_name, $verify_only) = @_;
    my $expected_watch = $watch_on ? 'on' : 'off';
    my $watch_re = qr/watch-$expected_watch(?:-list)?\.gif$/;
 
    #which aspect of the HTML id we will look at to determine
    #If the correct value is set
    my $s3_id_type;
    if (defined($page_name) and length($page_name)>0) {
        $s3_id_type = 'title';
    } else {
        $s3_id_type = 'class';
    }
    
    my $s3_expected = $watch_on ? 'watch on' : 'watch';
    my $is_s3 = 0;
    if ($self->{'skin'} eq 's3') { 
        $is_s3 = 1; 
    } 
    $page_name = '' if $page_name and $page_name =~ /^#/; # ignore comments
    $verify_only = '' if $verify_only and $verify_only =~ /^#/; # ignore comments

    unless ($page_name) {
        my $html_type = $is_s3 ? "a" : "img"; 
            
        return $self->_watch_page_xpath("//$html_type" . "[\@id='st-watchlist-indicator']", 
                                        $watch_re, $verify_only, $s3_expected, $is_s3, $s3_id_type);
    }

    # A page is specified, so assume we're on the watchlist page
    # We need to find which row the page we're interested in is in
    my $sel = $self->{selenium};
    my $row = 2; # starts at 1, which is the table header
    my $found_page = 0;
    (my $short_name = lc($page_name)) =~ s/\s/_/g;
    
    if ($is_s3) {
        my $xpath = '//a[@id=' . "'st-watchlist-indicator-$short_name" . "']";
        $xpath = qq{$xpath};
        my $expected_list = $watch_on ? 'Stop watching' : 'Watch';
        my $title= '';
        eval { $title = $sel->get_attribute("$xpath/\@title") };
        if (length($title)>0) {
            my $expected;
            if (defined($page_name) and length($page_name)>0) {
               $expected = $expected_list; # Expected title of the watch page for listview  
            } else { 
               $expected = $expected_watch; #Expected title of the watch page for 
            }
            $self->_watch_page_xpath($xpath, $watch_re, $verify_only, $expected, $is_s3, $s3_id_type);
            ok 1, "st-watch-page $expected_list - $page_name"
        } else {
            ok 0, "Failed to find watch icon\n";
        }
    } else {
        while (1) {
            my $xpath = qq{//div[\@id='st-watchlist-content']/div[$row]/div[2]/img}; 
            my $alt;
            eval { $alt = $sel->get_attribute("$xpath/\@alt") };
            last unless $alt;
            if ($alt eq $short_name) {
                $self->_watch_page_xpath($xpath, $watch_re);
                $found_page++;
                last;
            }
            else {
                warn "# Looking at watchlist for ($short_name), found ($alt)\n";
            }
            $row++;
        }
        ok $found_page, "st-watch-page $watch_on - $page_name"
            unless $ENV{ST_WF_TEST};
    }
}

sub _watch_page_xpath {
    my ($self, $xpath, $watch_re, $verify_only, $s3_expected, $is_s3, $id_type) = @_;
    my $sel = $self->{selenium};
    
    my $xpath_src = $is_s3 ? "$xpath/\@$id_type" : "$xpath/\@src";
    my $src = $sel->get_attribute($xpath_src);
    
    if ($is_s3) {
       #Capitalization is inconsisent for "stop watching" between list view
       #and page view.  Yes, really.
       if ($verify_only or lc($src) eq lc($s3_expected)) {
           is lc($src), lc($s3_expected), "$src - $s3_expected (Searching with $xpath)";
           return;
       }
    } else {
      if ($verify_only or $src=~ $watch_re) {
          like $src, $watch_re, "$xpath - $watch_re";
          return;
      }
    }
    

    $sel->click_ok($xpath, "clicking watch button");
    my $timeout = time + $self->{selenium_timeout} / 1000;
    while(1) {
        my $new_src = $sel->get_attribute($xpath_src);
        my $compare = 0;
        if ($is_s3) {
            $compare = (lc($new_src) eq lc($s3_expected));
        } else {
            $compare = ($new_src =~ $watch_re);
       }        
        
        last if $compare;
        select undef, undef, undef, 0.25; # sleep
        if ($timeout < time) {
            ok 0, 'Timeout waiting for watchlist icon to change';
            last;
        }
    }
}

=head2 st_is_watched( $watch_on, $page_name )

Validates that the current page is or is not on the watchlist.

The logic for the second argument are the same as for st_watch_page() above.

=cut

sub st_is_watched {
    my ($self, $watch_on, $page_name) = @_;
    return $self->st_watch_page($watch_on, $page_name, 'verify only');
}


=head2 st_rm_rf( $command_options )

Runs an command-line rm -Rf command with the supplied options.

Note that this will delete files, directories, and not prompt.  Use at your own risk.

=cut

sub st_rm_rf {
    my $self = shift;
    my $options = shift;
    unless (defined $options) {
        die "parameter required in call to st_rm_rf\n";
    }
    
    _run_command("rm -Rf $options", 'ignore output');
}

=head2 st_qa_setup_reports 

Run the command-line script st_qa_setup_reports that populates reports in order to test the usage growth report

=cut

sub st_qa_setup_reports {
    _run_command("st-qa-setup-reports",'ignore output');
}

=head2 st_admin( $command_options )

Runs st_admin command line script with the supplied options.

If the export-workspace command is used, I'll attempt to remove any existing
workspace tarballs before running the command.

=cut

sub st_admin {
    my $self    = shift;
    my $options = shift || '';
    my $verify  = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    # If we're exporting a workspace, attempt to remove the tarball first
    if ($options =~ /export-workspace.+--workspace(?:\s+|=)(\S+)/) {
        my $tarball = "/tmp/$1.1.tar.gz";
        if (-e $tarball) {
            diag "Deleting $tarball\n";
            unlink $tarball;
        }
    }

    # Invocations with redirected input/output or pipes *needs* to be done
    # against the shell, but simpler cmds can be done in-process.  Also have
    # to watch out for "st-admin help", which *has* to be shelled out for.
    #
    # We also have to use a bad calling pattern for this which *isn't* OOP
    # because we don't always have a '$self' that's derived from ST:WF:ST
    # (although it may be derived from ST:WF:Base).
    if ($options =~ /[\|<>]|help/) {
        _st_admin_shell_out($self, $options, $verify);
    }
    else {
        _st_admin_in_process($self, $options, $verify);
    }
}

sub _st_admin_in_process {
    my ($self, $options, $verify) = @_;

    {
        # over-ride "_exit()" so that we don't exit while running in-process.
        #
        # We *do*, however, want to make sure that we stop whatever we're
        # doing, so throw a fatal exception and get us outta there.
        require Socialtext::CLI;
        no warnings 'redefine';
        *Socialtext::CLI::_exit = sub { die "\n" };
    }

    # clear any in-memory caches that exist, so that we pick up changes that
    # _may_ have been made outside of this process.
    Socialtext::Cache->clear();

    # Run st-admin, in process.
    my @argv   = shellwords( $options );
    my $output = combined_from {
        eval { Socialtext::CLI->new( argv => \@argv )->run };
        if ($@) { warn $@ };
    };
    if ($verify) {
        like $output, qr/$verify/s, "st-admin $options";
    }
    else {
        diag "st-admin $options";
    }
}

sub _st_admin_shell_out {
    my ($self, $options, $verify) = @_;
    diag "st-admin $options";
    _run_command("st-admin $options", $verify);
}

#=head2 st_appliance_config($command_options)
#
#Runs st-appliance-config command line script with the supplied options.
#
#=cut

sub st_appliance_config {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;
    #ONLY runs on an appliance
    if (!Socialtext::AppConfig::_startup_user_is_human_user()) {
       #On An Appliance
       my $str = "sudo st-appliance-config $options";
       diag $str;
       _run_command($str, $verify);
    }
}

=head2 st_ldap( $command_options )

Runs st_bootstrap_openldap command line script with the supplied options.

If the "start" command is used, the OpenLDAP instance is fired off into the
background, which may take a second or two while we wait for it to start.

=cut

sub st_ldap {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    # If we're starting up an LDAP server, be sure to daemonize it and make
    # sure that it gets fired off into the background on its own.
    if ($options eq 'start') {
        $options .= ' --daemonize';
    }

    diag "st-ldap $options";
    _run_command("st-bootstrap-openldap $options", $verify);
}

=head2 st_config( $command_options )

Runs st_config command line script with the supplied options.

=cut

sub st_config {
    my $self = shift;
    my $options = shift || '';
    my $verify = shift;
    $verify = $self->quote_as_regex($verify) if $verify;

    diag "st-config $options";
    _run_command("st-config $options", $verify);
}

=head2 st_appliance_config_set( $command_options )

Runs `st-appliance-config set $command_options` in-process. Note that multiple
keys and values can be passed, so long as each param is separated by
whitespace.

=cut

sub st_appliance_config_set {
    my $self    = shift;
    my %options = split / +/, shift;

    require Socialtext::Appliance::Config;

    my $config = Socialtext::Appliance::Config->new();
    for my $key ( keys %options ) {
        $config->value( $key, $options{$key} );
    }

    $config->save();
    diag "st-appliance-config set "
        . join( ", ", map { "$_ $options{$_}" } keys %options ) . "\n";
}

=head2 st_admin_export_workspace_ok( $workspace )

Verifies that a workspace tarball was created.

The workspace parameter is optional.

=cut

sub st_admin_export_workspace_ok {
    my $self = shift;
    my $workspace = shift || $self->{workspace};
    my $tarball = "/tmp/$workspace.1.tar.gz";
    ok -e $tarball, "$tarball exists";
}

=head2 st_import_workspace( $options, $verify )

Imports a workspace from a tarball.  If the import is successful,
a test passes, if not, it fails.  The output is checked against
$verify.

C<$options> are passed through to "st-admin import-workspace"

=cut

sub st_import_workspace {
    my $self = shift;
    my $options = shift || '';
    my $verify = $self->quote_as_regex(shift);

    _run_command("st-admin import-workspace $options", $verify);
}

=head2 st_force_confirmation( $email, $password )

Forces confirmation of the supplied email address, and sets the user's
password to the second option.

=cut

sub st_force_confirmation {
    my ($self, $email, $password) = @_;

    require Socialtext::User;
    Socialtext::User->new(username => $email)->confirm_email_address();
    $self->st_admin("change-password --email '$email' --password '$password'",
                    'has been changed');
}

=head2 st_open_confirmation_uri

Open the correct url to confirm an email address.

=cut

sub st_open_confirmation_uri {
    my ($self, $email) = @_;

    require Socialtext::User;
    Socialtext::Cache->clear('email_conf');
    my $uri = Socialtext::User->new(username => $email)->confirmation_uri();
    # strip off host part
    $uri =~ s#.+(/nlw/submit/confirm)#$1#;
    $self->{selenium}->open_ok($uri);
}

=head2 st_should_be_admin( $email, $should_be )

Clicks the admin check box to for the given user.

=cut

sub st_should_be_admin {
    my ($self, $email, $should_be) = @_;
    my $method = ($should_be ? '' : 'un') . 'check_ok';
    $self->_click_user_row($email, $method, '/td[3]/input');
}

=head2 st_click_reset_password( $email )

Clicks the reset password check box to for the given user.

Also verifies that the checkbox is no longer checked.

=cut

sub st_click_reset_password {
    my ($self, $email, $should_be) = @_;
    my $chk_xpath = $self->_click_user_row($email, 'check_ok', '/td[4]/input');
    ok !$self->is_checked($chk_xpath), 'reset password checkbox not checked';
}

sub type_lookahead_ok {
    my ($self, $locator, $text) = @_;
    $self->wait_for_element_present_ok($locator);
    $self->type_ok($locator, $text);
    $self->{selenium}->do_command("keyUp", $locator, substr($text,-1));
}

sub _click_user_row {
    my ($self, $email, $method_name, $click_col) = @_;
    my $sel = $self->{selenium};

    my $row = 1;
    my $chk_xpath;
    while(1) {
        $row++;
        my $row_email = $sel->get_text("//tbody/tr[$row]/td[2]");
        diag "row=$row email=($row_email)";
        last unless $row_email;
        next unless $email and $row_email =~ /\Q$email\E/;
        $chk_xpath = "//tbody/tr[$row]$click_col";
        
        $sel->$method_name($chk_xpath);
        if ($self->{'skin'} eq 's3') {
            $self->click_and_wait('link=Save');
            $sel->text_like('contentContainer', qr/\QChanges Saved\E/);
         } elsif ($self->{'skin'} eq 's2') {
            $self->click_and_wait('Button');
            $sel->text_like('st-settings-section', qr/\QChanges Saved\E/);
         } else {
            ok 0, "Unknown skin type: $self->{'skin'}";
        }
        return $chk_xpath;
    }
    ok 0, "Could not find '$email' in the table";
    return;
}

sub _run_command {
    Socialtext::WikiFixture::SocialBase->can('_run_command')->(@_);
}

=head1 AUTHOR

Luke Closs, C<< <luke.closs at socialtext.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-socialtext-editpage at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Socialtext-WikiTest>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Socialtext::WikiFixture::Socialtext

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Socialtext-WikiTest>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Socialtext-WikiTest>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Socialtext-WikiTest>

=item * Search CPAN

L<http://search.cpan.org/dist/Socialtext-WikiTest>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Luke Closs, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
