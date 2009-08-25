package Socialtext::Search::Solr::Factory;
# @COPYRIGHT@
use strict;
use warnings;

use Socialtext::l10n qw(system_locale);
use Socialtext::Search::Solr::Indexer;
# use Socialtext::Search::Solr::Searcher;
use Socialtext::Search::Config;
use Socialtext::AppConfig;
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
    
    my $class = 'Socialtext::Search::Solr::' . $kind;
    return $class->new( ws_name => $ws_name );
}

1;
__END__

=pod

=head1 NAME

Socialtext::Search::Solr::Factory

=head1 SEE

L<Socialtext::Search::AbstractFactory> for the interface definition.

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT & LICENSE

Copyright 2009 Socialtext, Inc., all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
