package Socialtext::Search::Solr::Searcher;
# @COPYRIGHT@
use Moose;
use MooseX::AttributeInflate;
use Socialtext::Log qw(st_log);
use Socialtext::Timer;
use Socialtext::Search::AbstractFactory;
use Socialtext::Search::Solr::QueryParser;
use Socialtext::Search::SimpleAttachmentHit;
use Socialtext::Search::SimplePageHit;
use Socialtext::Search::SignalHit;
use Socialtext::Search::PersonHit;
use Socialtext::Search::Utils;
use Socialtext::AppConfig;
use Socialtext::Exceptions;
use Socialtext::Workspace;
use Socialtext::JSON qw/decode_json/;
use WebService::Solr;
use namespace::clean -except => 'meta';

=head1 NAME

Socialtext::Search::Solr::Searcher

=head1 SYNOPSIS

  my $s = Socialtext::Search::Solr::Factory->create_searcher($workspace_name);
  $s->search(...);

=head1 DESCRIPTION

Search the solr index.

=cut

extends 'Socialtext::Search::Searcher';
extends 'Socialtext::Search::Solr';

has '_default_rows' => (is => 'ro', isa => 'Num', default => 20);

has_inflated 'query_parser' =>
    (is => 'ro', isa => 'Socialtext::Search::Solr::QueryParser',
     handles => [qw/parse/]);

# Perform a search and return the results.
sub search {
    my $self = shift;
    my ($thunk, $num_hits) = $self->begin_search(@_);
    return @{ $thunk->() || [] };
}

# Start a search, but don't process the results.  Return a thunk and a number
# of hits.  The thunk returns an arrayref of processed results.
sub begin_search {
    my ( $self, $query_string, $authorizer, $workspaces, %opts ) = @_;
    my $name = $workspaces ? join(',', @$workspaces) : $self->ws_name;
    $name ||= $opts{doctype} || 'unknown';
    _debug("Searching $name with query: $query_string");

    my ($docs, $num_hits) = $self->_search($query_string, undef, $workspaces, %opts);

    my $thunk = sub {
        _debug("Processing $name thunk");
        Socialtext::Timer->Continue('solr_begin');
        my $results = $self->_process_docs($docs);
        Socialtext::Timer->Continue('solr_begin');
        return $results;
    };
    return ($thunk, $num_hits);
}

# Parses the query string and returns the raw Solr hit results.
sub _search {
    my ( $self, $query_string, $authorizer, $workspaces, %opts) = @_;
    $opts{limit}   ||= $self->_default_rows;
    $opts{timeout} ||= Socialtext::AppConfig->search_time_threshold();

    my @account_ids;
    if ($opts{account_ids}) {
        @account_ids = @{ $opts{account_ids} };
    }
    else {
        @account_ids = $opts{viewer}->accounts(ids_only => 1);
    }

    my $query = $self->parse(lc($query_string), \@account_ids);
    return ([], 0) if $query =~ m/^(?:\*|\?)/;
    $self->_authorize( $query, $authorizer );

    Socialtext::Timer->Continue('solr_raw');
    my $filter_query;
    if ($workspaces and @$workspaces) {
        $filter_query = "(doctype:attachment OR doctype:page) AND ("
              . join(' OR ', map { "w:$_" }
                map { Socialtext::Workspace->new(name => $_)->workspace_id }
                    @$workspaces) . ")";
    }
    elsif ($opts{doctype}) {
        $filter_query = "doctype:$opts{doctype}";
        if ($opts{viewer}) {
            $filter_query .= " AND ("
                . join(' OR ', map { "a:$_" } @account_ids)
                . ")";

            if ($opts{doctype} eq 'signal') {
                my $viewer_id = $opts{viewer}->user_id;
                $filter_query = [
                    $filter_query,
                    "pvt:0 OR (pvt:1 AND "
                        . "(dm_recip:$viewer_id OR creator:$viewer_id))",
                ];
            }
            elsif ($opts{doctype} eq 'person') {
                if ($query !~ m/\w+\"?:/) {
                    $query = "name_pf_t:$query";
                }
            }
        }
    }

    # See: http://wiki.apache.org/solr/CommonQueryParameters
    my $query_type = 'dismax';
    $query_type = 'standard' if $query =~ m/\b[a-z_]+:/i;
    $query_type = 'standard' if $query =~ m/\*|\?/;
    my @sort = $self->_sort_opts($opts{order}, $opts{direction}, $query_type);
    my $query_hash = {
        # fl = Fields to return
        fl => 'id score doctype',

        # qt = Query Type
        qt => $query_type,

        # fq = Filter Query - superset of docs to return from
        ($filter_query ? (fq => $filter_query) : ()),
        rows        => $opts{limit},
        start       => $opts{offset} || 0,
        timeAllowed => $opts{timeout},
        @sort,
    };
    my $response = $self->solr->search($query, $query_hash);

    if ($response->content->{responseHeader}->{partialResults}) {
        Socialtext::Exception::SearchTimeout->throw();
    }

    my $docs = $response->docs;
    my $num_hits = $response->pager->total_entries();
    Socialtext::Timer->Pause('solr_raw');

    _debug("Found $num_hits matches");
    return ($docs, $num_hits);
}

sub _sort_opts {
    my $self       = shift;
    my $order      = lc(shift || '');
    my $direction  = shift || 'desc';
    my $query_type = shift;

    # Map the UI options into Solr fields
    my %sortable = (
        relevance => 'score',
        date => 'date',
        subject => 'plain_title',
        revision_count => 'revisions',
        create_time => 'created',
        workspace => 'w_title',
        sender => 'creator_name',
    );

    # If no valid sort order is supplied, then we use either a date sort or a
    # score sort.
    return ('sort' => $query_type eq 'standard' ? 'date desc' : 'score desc')
        unless $sortable{$order};

    # If a valid sort order is supplied, then we secondary sort by date,
    # unless the primary sort is already date.
    my $sec_sort = $order eq 'date' ? 'score desc' : 'date desc';
    return ('sort' => "$sortable{$order} $direction, $sec_sort");
}

# Either do nothing if the query's authorized, or throw NoSuchWorkspace or
# Auth.
sub _authorize {
    my ( $self, $query, $authorizer ) = @_;
    return unless defined $authorizer;

    unless ($authorizer->( $self->ws_name )) {
        _debug("authorizer failed for ".$self->ws_name);
        Socialtext::Exception::Auth->throw;
    }
}

sub _process_docs {
    my ( $self, $docs ) = @_;
    _debug("Processing search results");

    my @results;
    my %seen;
    for my $doc (@$docs) {
        my $doc_id = $doc->value_for('id');
        next if exists $seen{ $doc_id };
        $seen{$doc_id} = 1;
        push @results, $self->_make_result($doc);
    }

    return \@results;
}

sub _make_result {
    my ($self, $doc) = @_;
    my $key     = $doc->value_for('id');
    my $doctype = $doc->value_for('doctype');
    my $score   = $doc->value_for('score');

    if ($doctype eq 'signal') {
        return Socialtext::Search::SignalHit->new(
            score => $score,
            signal_id => $key,
        );
    }
    if ($doctype eq 'person') {
        return Socialtext::Search::PersonHit->new(
            score => $score,
            user_id => $key,
        );
    }
    else {
        my ($workspace_id, $page, $attachment) = split /:/, $key, 3;

        my $ws = Socialtext::Workspace->new(workspace_id => $workspace_id);
        my $ws_name = $ws->name;

        my $hit = {
            snippet => 'No worky',
            key     => $key,
            score   => $doc->value_for('score'),
        };

        return
            defined $attachment
            ? Socialtext::Search::SimpleAttachmentHit->new($hit, $ws_name,
            $page, $attachment)
            : Socialtext::Search::SimplePageHit->new($hit, $ws_name, $page);
    }
}

# Send a debugging message to syslog.
sub _debug {
    my $msg = shift || "(no message)";
    $msg = __PACKAGE__ . ": $msg";
    st_log->debug($msg);
}

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Socialtext::Search::Solr::Searcher
- Solr Socialtext::Search::Searcher implementation.

=head1 SEE

L<Socialtext::Search::Searcher> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
