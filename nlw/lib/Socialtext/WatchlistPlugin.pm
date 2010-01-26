# @COPYRIGHT@
package Socialtext::WatchlistPlugin;
use strict;
use warnings;

use base 'Socialtext::Query::Plugin';
use Class::Field qw( const field );
use Socialtext::EmailNotifier;
use Socialtext::Watchlist;
use Socialtext::l10n qw( loc );
use Socialtext::Events;
use Socialtext::Pageset;

const class_id    => 'watchlist';
const class_title => loc('Watchlist');
const cgi_class   => 'Socialtext::Watchlist::CGI';
const listview_extra_columns => { watchlist => 1 };
field 'lock_handle';

sub register {
    my $self     = shift;
    my $registry = shift;
    $registry->add( action     => 'display_watchlist' );
    $registry->add( action     => 'watchlist' );
    $registry->add( action     => 'add_to_watchlist' );
    $registry->add( action     => 'remove_from_watchlist' );
    $registry->add( preference => $self->watchlist_notify_frequency );
    $registry->add( preference => $self->watchlist_links_only );
}

sub init {
    my $self = shift;
    $self->SUPER::init(@_);
    $self->user_plugin_directory(
        $self->hub->current_user->email_address
    );
}

sub watchlist_notify_frequency {
    my $self = shift;
    my $p    = $self->new_preference('watchlist_notify_frequency');
    $p->query(loc('How frequently would you like to receive watchlist emails?'));
    $p->type('pulldown');
    my $choices = [
        0     => 'Never',
        1     => 'Every Minute',
        5     => 'Every 5 Minutes',
        15    => 'Every 15 Minutes',
        60    => 'Every Hour',
        360   => 'Every 6 Hours',
        1440  => 'Every Day',
        4320  => 'Every 3 Days',
        10080 => 'Every Week',
    ];
    $p->choices($choices);
    $p->default(1440);
    return $p;
}

sub watchlist_links_only {
    my $self = shift;
    my $p    = $self->new_preference('watchlist_links_only');
    $p->query(
        loc('What information about changed pages do you want in email digests?'));
    $p->type('radio');
    my $choices = [
        condensed => loc('Page name and link only'),
        expanded  => loc('Page name and link, plus author and date'),
    ];
    $p->choices($choices);
    $p->default('expanded');
    return $p;
}

sub page_watched {
    my $self      = shift;
    my $watchlist = Socialtext::Watchlist->new(
        user      => $self->hub->current_user,
        workspace => $self->hub->current_workspace
    );

    my $page = $self->hub->pages->current;
    if ( $watchlist->has_page( page => $page ) ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub pages_in_watchlist {
    my $self      = shift;
    my $user      = shift;
    my $workspace = shift;
    my $pages     = shift;
    my @return;
    my $watchlist = Socialtext::Watchlist->new(
        user      => $user,
        workspace => $workspace
    );
    foreach my $page (@$pages) {
        push( @return, $page )
            if ( $watchlist->has_page( page => $page ) );
    }
    return ( \@return );
}

sub add_to_watchlist {
    my $self = shift;
    $self->_reject_guest;
    my $watchlist = Socialtext::Watchlist->new(
        user      => $self->hub->current_user,
        workspace => $self->hub->current_workspace
    );

    my $page = $self->hub->pages->new_from_name( $self->cgi->page );
    if ( !$watchlist->has_page( page => $page ) ) {
        $watchlist->add_page( page => $page );
    }

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'watch_add',
        page => $page,
    });
    return '1';
}

sub remove_from_watchlist {
    my $self = shift;
    $self->_reject_guest;
    my $watchlist = Socialtext::Watchlist->new(
        user      => $self->hub->current_user,
        workspace => $self->hub->current_workspace
    );

    if ( $self->cgi->page ) {
        my $page = $self->hub->pages->new_from_name( $self->cgi->page );
        $watchlist->remove_page( page => $page );
        $self->_record_watch_delete($page);
        return '0';
    }
    else {
        my @pages_to_remove = map { split /\000/ } $self->cgi->selected;
        for my $checked_page (@pages_to_remove) {
            my $page = $self->hub->pages->new_page($checked_page);
            $watchlist->remove_page( page => $page );
            $self->_record_watch_delete($page);
        }
        $self->redirect("action=display_watchlist");
    }
}

sub _record_watch_delete {
    my ($self, $page) = @_;

    Socialtext::Events->Record({
        event_class => 'page',
        action => 'watch_delete',
        actor => $self->hub->current_user,
        workspace => $self->hub->current_workspace,
        page => $page,
        revision_count => $page->revision_count,
        revision_id => $page->revision_id,
    });
}

sub _reject_guest {
    my $self = shift;
    if ( $self->hub()->current_user()->is_guest() ) {
        Socialtext::Challenger->Challenge(
            type => 'watchlist_requires_account' );
    }
}

sub watchlist {
    my $self = shift;
    $self->display_watchlist();
}

sub display_watchlist {
    my $self = shift;
    $self->_reject_guest();
    my $watchlist = Socialtext::Watchlist->new(
        user      => $self->hub->current_user,
        workspace => $self->hub->current_workspace
    );

    my @pages = $watchlist->pages;
    if ( $#pages < 0 ) {
        my $empty_message = loc("Your Watchlist in [_1] is empty.",
            $self->hub->current_workspace->title);
        return $self->template_render(
            template => 'view/empty_watchlist',
            vars     => {
                $self->hub->helpers->global_template_vars,
                action        => 'display_watchlist',
                title         => loc("Watchlist"),
                empty_message => $empty_message,
                feeds => $self->_feeds( $self->hub->current_workspace ),
                enable_unplugged =>
                    $self->hub->current_workspace->enable_unplugged,
                unplug_uri    => "?action=unplug;watchlist=default",
                unplug_phrase =>
                    loc("Click this button to save the pages you're watching for offline use."),
            },
        );
    }
    else {
        return $self->watchlist_changes( \@pages );
    }
}

sub _feeds {
    my $self = shift;
    my $workspace = shift;

    my $feeds = $self->SUPER::_feeds($workspace);
    $feeds->{rss}->{page} = {
        title => $feeds->{rss}->{watchlist}->{title},
        url => $feeds->{rss}->{watchlist}->{url},
    };
    $feeds->{atom}->{page} = {
        title => $feeds->{atom}->{watchlist}->{title},
        url => $feeds->{atom}->{watchlist}->{url},
    };

    return $feeds;
}

sub watchlist_changes {
    my $self  = shift;
    my $pages = shift;

    my %sortdir = %{ $self->sortdir };
    if ( $self->cgi->sortby ) {
        $self->result_set( $self->sorted_result_set( \%sortdir ) );
    }
    else {
        $self->result_set( $self->new_result_set() );

        my $watchlist;
        foreach my $page (@$pages) {
            my $page_object = $self->hub->pages->new_page($page);

            # If the page has been purged take it out of the watchlist
            if ( !$page_object->active ) {
                $watchlist ||= Socialtext::Watchlist->new(
                    user      => $self->hub->current_user,
                    workspace => $self->hub->current_workspace
                );
                $watchlist->remove_page( page => $page_object );
                next;
            }

            $self->push_result($page_object);
        }
        $self->result_set( $self->sorted_result_set( \%sortdir ) );
    }
    $self->result_set->{display_title} = loc("Pages You're Watching");
    $self->result_set->{hits} = @{$self->result_set->{rows}};

    $self->write_result_set;

    return $self->display_results(
        \%sortdir,
        feeds         => $self->_feeds( $self->hub->current_workspace ),
        unplug_uri    => "?action=unplug;watchlist=default",
        unplug_phrase =>
            "Click this button to save the pages you're "
            . 'watching for offline use.',
        Socialtext::Pageset->new(
            cgi => {$self->cgi->all},
            total_entries => $self->result_set->{hits},
        )->template_vars(),
    );
}

#------------------------------------------------------------------------------#
package Socialtext::Watchlist::CGI;

use base 'Socialtext::Query::CGI';
use Socialtext::CGI qw( cgi );

cgi 'page' => '-clean_path';
cgi 'title';
cgi 'watchlist';
cgi 'selected';
cgi 'id' => '-clean_path';
cgi 'offset';

1;
