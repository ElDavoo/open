package Socialtext::Rest::Groups;
# @COPYRIGHT@
use warnings;
use strict;
use base 'Socialtext::Rest::Collection';
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::Permission;
use Socialtext::Group;
use Socialtext::User;
use Socialtext::Log qw/st_log/;

# Anybody can see these, since they are just the list of workspaces the user
# has 'selected'.
sub permission { +{} }

sub collection_name { 'Groups' }

sub _entities_for_query {
    my $self = shift;
    my $user = $self->rest->user();

    my $group_cursor = Socialtext::Group->All();
    if ($user->is_business_admin) {
        return $group_cursor->all;
    }

    my @groups;
    while (my $g = $group_cursor->next) {
        eval {
            if ($g->creator->user_id == $user->user_id 
                    or $g->has_user($user)) {
                push @groups, $g;
            }
        };
        warn $@ if $@;
    }
    return @groups;
}

sub _entity_hash {
    my $self  = shift;
    my $group = shift;

    return $group->to_hash( show_members => $self->{_show_members} );
}

sub GET_json {
    my ( $self, $rest ) = @_;

    Socialtext::Timer->Continue("GET_json");
    my $rv = eval { $self->if_authorized( 'GET', sub {
        Socialtext::Timer->Continue('get_resource');
        $self->{_show_members} = $rest->query->param('show_members') ? 1 : 0;
        my $resource = $self->get_resource($rest);
        Socialtext::Timer->Pause('get_resource');
        $resource = [] unless (ref $resource && @$resource);

        my %new_headers = (
            -status => HTTP_200_OK,
            -type => 'application/json; charset=UTF-8',
            '-cache-control' => 'private',
            # override those with:
            $rest->header,
        );
        $rest->header(%new_headers);
        return $self->resource_to_json($resource);
    })};
    Socialtext::Timer->Pause("GET_json");
    if (my $e = $@) {
        if (Exception::Class->caught('Socialtext::Exception::Auth')) {
            return $self->not_authorized;
        }
        elsif (Exception::Class->caught('Socialtext::Exception')) {
            $e->rethrow;
        }
        else {
            # Rely on error thrower to set HTTP headers properly.
            my ($error) = split "\n", $e; # first line only
            st_log->info("Rest Collection Error: $e");
        }
    }

    return $rv;
}

1;
