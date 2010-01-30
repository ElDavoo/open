# @COPYRIGHT@
package Socialtext::GoogleSearchPlugin;
use strict;
use warnings;
use base 'Socialtext::Plugin';

use Class::Field qw( const );
use Socialtext::URI;
use REST::Google::Search;
use Socialtext::Encode;

const limit => 8;
const class_title => 'google retrieval';

sub class_id { 'google_search' }

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(wafl => $_ => 'Socialtext::GoogleSearchPlugin::Wafl')
        for qw( googlesearch googlesoap ); # Keep "googlesoap" compat
}

sub get_result {
    my $self = shift;
    my $query = shift;

    if ($query =~ /[^\x00-\x7F]/) {
        return {
            error => "Sorry, Google Search currently only accepts plain English characters: <b>" . Socialtext::Encode::ensure_is_utf8($query) . "</b>"
        };
    }

    REST::Google::Search->http_referer(
        Socialtext::URI::uri(path => '/')
    );

    my @results;

    # The "rsz=large" below returns 8 results, which coincides
    # with our expected limit of 8; nevertheless, use a while
    # loop so we can adjust the limit later.
    while (@results < $self->limit) {
        my $res = REST::Google::Search->new(
            q => $query,
            rsz => 'large',
            start => 0+@results,
        );

        if ($res->responseStatus !~ /^2/) {
            last if @results;
            return { error => $res->responseStatus };
        }

        last unless $res->responseData->results;
        push @results, $res->responseData->results;
    }

    return {
        resultElements => [
            map { +{
                title => $_->title,
                URL => $_->url,
                snippet => $_->content
            } } @results[ 0..($self->limit-1) ]
        ]
    };
}

package Socialtext::GoogleSearchPlugin::Wafl;
use Socialtext::l10n qw(loc);

use Socialtext::Formatter::WaflPhrase;
use base 'Socialtext::Formatter::WaflPhraseDiv';

sub html {
    my $self = shift;
    my $query = $self->arguments;

    return $self->syntax_error unless defined $query and $query =~ /\S/;

    return $self->pretty(
        $query,
        $self->hub->google_search->get_result($query)
    );
}

sub pretty {
    my $self = shift;
    my $query = shift;
    my $result = shift;
    $self->hub->template->process('wafl_box.html',
        query => $query,
        wafl_title => loc('Search for "[_1]"', $query),
        wafl_link => "http://www.google.com/search?q=$query",
        items => $result->{resultElements},
        error => $result->{error},
    );
}

1;

