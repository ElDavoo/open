package Socialtext::Rest::PageWatchers;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::Watchlist;

use base 'Socialtext::Rest::Collection';

sub allowed_methods { 'GET' };

sub collection_name {
    'Users Watching ' . shift->page->metadata->Subject;
}

sub _resource_to_text {
    my $self = shift;
    my $elem = shift;
    return $elem->[0]{username};
}

sub element_list_item {
    my $self = shift;
    my $elem = shift;
    my $name = $elem->{best_full_name};
    my $uri  = '/data/users/' . $elem->{username};
    return qq{<li><a href="$uri">$name</a></li>\n};
}

sub _entities_for_query {
    my $self = shift;
    my $ws   = $self->workspace;
    my $page = $self->page;
    my $cursor = Socialtext::Watchlist->Users_watching_page(
        $ws->workspace_id, $page->id,
    );
    return $cursor->all;
}

sub _entity_hash {
    my $self   = shift;
    my $entity = shift;
    return $entity->to_hash(minimal => 1);
}

1;

=head1 NAME

Socialtext::Rest::PageWatchers - Retrieve watchers of a page via REST

=head1 SYNOPSIS

  GET /data/workspaces/:ws/pages/:pname/watchers

=head1 DESCRIPTION

Provide a list of Users (in a minimal representation) that are watching a given Page.

=cut
