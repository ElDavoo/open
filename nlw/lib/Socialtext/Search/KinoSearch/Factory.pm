# @COPYRIGHT@
package Socialtext::Search::KinoSearch::Factory;
use strict;
use warnings;

use Socialtext::l10n qw(system_locale);
use File::Basename 'dirname';
use Socialtext::File 'ensure_directory';
use Socialtext::Search::KinoSearch::Analyzer;
use Socialtext::Search::KinoSearch::Indexer;
use Socialtext::Search::KinoSearch::Searcher;
use Socialtext::Search::Config;
use Socialtext::AppConfig;
use Socialtext::Exceptions;
use Socialtext::System ();
use base 'Socialtext::Search::AbstractFactory';

# Rather than create an actual object (since there's no state), just return
# the class name.  This will continue to make all the methods below work.
sub new { $_[0] }

sub create_searcher {
    my ( $self, $ws_name, %param ) = @_;
    return $self->_create( "Searcher", $ws_name, %param );
}

sub create_indexer {
    my ( $self, $ws_name, %param )  = @_;
    return $self->_create( "Indexer", $ws_name, %param );
}

sub _create {
    my $self = shift;
    my ( $kind, $ws_name, %param ) = @_;
    $param{config_type} ||= 'live';
    $param{language}    ||= 'en';
    
    my $config = Socialtext::Search::Config->new(  
        mode => $param{config_type},
    );

    $config or return;
    
    my $class = 'Socialtext::Search::KinoSearch::' . $kind;
    return $class->new( $ws_name, $param{language}, 
        $config->index_directory(workspace => $ws_name),
        $self->_analyzer($param{language}), $config );
}


sub _analyzer {
    my $self = shift;
    my $lang = system_locale();
    return Socialtext::Search::KinoSearch::Analyzer->new( language => $lang );
}

sub search_on_behalf {
    my $self               = shift;
    my $workspaces         = shift;
    my $query              = shift;
    my $user               = shift;
    my $no_such_ws_handler = shift;
    my $authz_handler      = shift;

    my $hit_threshold = Socialtext::AppConfig->search_warning_threshold || 500;

    # workspace search thunks hold open filehandles, so we need to impose a
    # safety limit.
    my $fh_threshold = Socialtext::System::open_filehandle_limit();
    $fh_threshold *= 0.75;

    my $total_hits = 0;
    my @hits;
    my @hit_thunks;

    # sorting workspaces hopefully prevents KS deadlocks:
    for my $workspace (sort @$workspaces) {
        eval {
            my ($thunk, $ws_hits) =
                $self->_search_workspace($user, $workspace, $query);
            $total_hits += $ws_hits;
            # don't track any more thunks if we've exceeded the threshold
            push @hit_thunks, $thunk if ($total_hits <= $hit_threshold);
        };
        if (my $e = $@) {
            die $e unless ref $e;
            if ($e->isa('Socialtext::Exception::NoSuchWorkspace')) {
                $e->rethrow unless defined $no_such_ws_handler;
                $no_such_ws_handler->($e);
            }
            elsif ($e->isa('Socialtext::Exception::Auth')) {
                $e->rethrow unless defined $authz_handler;
                $authz_handler->($e) if defined $authz_handler;
            }
            elsif ($e->isa('Socialtext::Exception::TooManyResults')) {
                $total_hits += $e->{num_results};
            }
            else {
                $e->rethrow;
            }
        }

        if ($total_hits > $hit_threshold) {
            # Throw away the results; we won't display them.
            # Keep searching to get the grand total, however.
            @hit_thunks = @hits = ();
        }
        elsif (Socialtext::System::open_filehandles() > $fh_threshold) {
            # Evaluate the thunks to free up file handles
            push @hits, map { @{ $_->() || [] } } @hit_thunks;
            @hit_thunks = ();
        }
    }

    Socialtext::Exception::TooManyResults->throw(
        num_results => $total_hits,
    ) if $total_hits > $hit_threshold;

    # Evaluate the thunks now that we're sure that the results are of
    # reasonable size
    push @hits, map { @{ $_->() || [] } } @hit_thunks;
    @hit_thunks = ();

    # Re-rank all hits by the raw_hit's score (this bleeds some implementation)
    return [ sort { $b->hit->{score} cmp $a->hit->{score} } @hits ], $total_hits;
}

sub _search_workspace {
    my $self = shift;
    my ($user, $workspace, $query) = @_;

    my $searcher = $self->create_searcher($workspace);
    my $authorizer = $self->_make_authorizer($user);

    my ($thunk, $ws_hits);
    if ($searcher->can('begin_search')) {
        ($thunk, $ws_hits) =
            $searcher->begin_search($query, $authorizer);
    }
    else {
        my @one_ws_hits = $searcher->search($query, $authorizer);
        $thunk = sub { \@one_ws_hits };
        $ws_hits = @one_ws_hits;
    }

    return ($thunk, $ws_hits);
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::KinoSearch::Factory

=head1 SEE

L<Socialtext::Search::AbstractFactory> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
