# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Searcher;
use strict;
use warnings;

use base 'Socialtext::Search::Searcher';
use Class::Field qw(field);
use KinoSearch::Highlight::Highlighter;
use KinoSearch::Searcher;
use Socialtext::Log qw(st_log);
use Socialtext::Timer;
use Socialtext::Search::AbstractFactory;
use Socialtext::Search::KinoSearch::Factory;
use Socialtext::Search::KinoSearch::QueryParser;
use Socialtext::Search::SimpleAttachmentHit;
use Socialtext::Search::SimplePageHit;
use Socialtext::Search::Utils;
use Socialtext::AppConfig;
use Socialtext::Exceptions;

field 'analyzer';
field 'config';
field 'index';
field 'searcher';
field 'ws_name';
field 'language';

sub new {
    my ( $class, $ws_name, $language, $index, $analyzer, $config ) = @_;
    my $self = bless {}, $class;

    # Create Searcher
    $self->analyzer($analyzer);
    $self->index($index);
    $self->language($language);
    $self->ws_name($ws_name);
    $self->config($config);

    return $self;
}

# Perform a search and return the results.
sub search {
    my $self = shift;
    my ($thunk, $num_hits) = $self->begin_search(@_);
    return @{ $thunk->() || [] };
}

# Start a search, but don't process the results.  Return a thunk and a number
# of hits.  The thunk returns an arrayref of processed results.
sub begin_search {
    my ( $self, $query_string, $authorizer ) = @_;
    $self->_init_searcher();
    _debug("Searching ".$self->ws_name." with query: $query_string");

    my $hits = $self->_search( $query_string, $authorizer );
    return (sub {}, 0) unless $hits->total_hits;

    my $thunk = sub {
        _debug("Processing ".$self->ws_name." thunk");
        Socialtext::Timer->Continue('ks_process');
        my $hits_processor_method = $self->config->hits_processor_method;
        my $results = eval { [$self->$hits_processor_method($hits)] };
        my $err = $@;
        Socialtext::Timer->Continue('ks_process');
        die $err if $err;
        return $results;
    };
    return ($thunk, $hits->total_hits);
}

# Load up the Searcher.
sub _init_searcher {
    my $self     = shift;
    my $index    = $self->index;
    my $analyzer = $self->analyzer;

    # Ensure the index exists, this creates it if it does not.
    my $factory = Socialtext::Search::AbstractFactory->GetFactory();
    $factory->create_indexer( $self->ws_name );

    $self->searcher(
        KinoSearch::Searcher->new(
            invindex => $index,
            analyzer => $analyzer,
        )
    );
    _debug( "Searcher created: index=$index analyzer=" . ref($analyzer) );
}

# Parses the query string and returns the raw KinoSearch hit results.
sub _search {
    my ( $self, $query_string, $authorizer ) = @_;

    my $query_parser_method = $self->config->query_parser_method;
    my $query = $self->$query_parser_method($query_string);
    $self->_authorize( $query, $authorizer );
    _debug("Performing actual search for query in ".$self->ws_name);

    Socialtext::Timer->Continue('ks_raw');
    my $hits = $self->searcher->search( query => $query );
    # XXX: calling total_hits may actualize part of the KS result.
    # Keep it here between the timers - stash
    my $num_hits = $hits->total_hits;
    Socialtext::Timer->Pause('ks_raw');

    _debug("Found $num_hits matches");
    my $hit_limit = Socialtext::AppConfig->search_warning_threshold;
    Socialtext::Exception::TooManyResults->throw(
        num_results => $num_hits
    ) if $num_hits > $hit_limit;

    return $hits;
}

# Either do nothing if the query's authorized, or throw NoSuchResource or
# Auth.
sub _authorize {
    my ( $self, $query, $authorizer ) = @_;

    return unless defined $authorizer;

    unless ($authorizer->( $self->ws_name )) {
        _debug("authorizer failed for ".$self->ws_name);
        Socialtext::Exception::Auth->throw;
    }
}

# Munge the query to our liking, parse the query and return a query object.
# The default fields searched when no "field:" prefix is given on a term are
# the ones mentioned below in the "fields =>" parameter.
sub _parse_query {
    my ( $self, $query_string ) = @_;
    _debug("Parsing query using _parse_query()" );
    my $parser_class = 'Socialtext::Search::KinoSearch::QueryParser';
    return $parser_class->new( searcher => $self )->parse($query_string);
}

sub _process_hits {
    my ( $self, $hits ) = @_;
    _debug("Processing search results");
    my @results;
    my %seen;

    if ( $self->config->excerpt_text ) {
        my $highlighter = KinoSearch::Highlight::Highlighter->new(
            excerpt_field  => 'text',
            excerpt_length => 400
        );
        $hits->create_excerpts( highlighter => $highlighter );
    }

    $hits->seek( 0, $hits->total_hits );
    while ( my $hit = $hits->fetch_hit_hashref ) {
        next if exists $seen{ $hit->{key} };
        $seen{ $hit->{key} } = 1;
        _debug( "Contructing hit object for " . $hit->{key} );
        push @results, $self->_make_result( $hit, $self->ws_name );
    }

    return @results;
}

sub _make_result {
    my ( $self, $hit, $ws_name ) = @_;
    my $key = $hit->{key};
    my ( $page, $attachment ) = split /:/, $key, 2;
    return
        defined $attachment
        ? Socialtext::Search::SimpleAttachmentHit->new( $hit, $ws_name, $page, $attachment )
        : Socialtext::Search::SimplePageHit->new( $hit, $ws_name, $page );
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

1;

=head1 NAME

Socialtext::Search::KinoSearch::Searcher
- KinoSearch Socialtext::Search::Searcher implementation.

=head1 SEE

L<Socialtext::Search::Searcher> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
