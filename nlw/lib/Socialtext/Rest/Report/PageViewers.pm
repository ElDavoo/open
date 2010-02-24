package Socialtext::Rest::Report::PageViewers;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::ReportAdapter';
with 'Socialtext::Rest::Pageable';

=head1 NAME

Socialtext::Rest::Report::PageViewers - Viewers of a given page

=head1 SYNOPSIS

  GET /data/workspaces/:ws/pages/:page_id/viewers

=head1 DESCRIPTION

Shows the people that viewed the given page recently.

=cut

# Note: We're not using Socialtext::Rest::Pageable's get_resource() because
# we do not need to provide backwards compatible interfaces, and we want
# more control over the REST responses.

sub start_time { shift->rest->query->param('start_time') || 'now' }
sub duration   { shift->rest->query->param('duration')   || '-3months' }

override 'GET_json' => sub {
    my $self = shift;

    return $self->error(400, 'Bad request', $@) if $@;

    my $data = eval { $self->_get_entities() };
    return $data unless ref($data);
    return $self->error(400, 'Bad request', $@) if $@;

    $self->rest->header(-type => 'application/json');
    return encode_json({
        startIndex => $self->start_index+0,
        itemsPerPage => $self->items_per_page+0,
        totalResults => $self->_get_total_results,
        start_time => $self->start_time(),
        duration   => $self->duration(),
        entry => [ grep {defined} map { $self->_entity_hash($_) } @$data ],
    });
};

sub _get_entities {
    my $self = shift;
    my $user = $self->rest->user;
    my $page = $self->page;
    my $report = eval { $self->adapter->_build_report(
        'ViewersByPage', {
            start_time  => $self->start_time,
            duration    => $self->duration,
            type        => 'raw',
            workspace   => $self->hub->current_workspace->name,
            page_id     => $page->id,
        }, $user,
    ) };
    return $self->not_authorized unless $report->is_viewable_by($user);
    my $all_data = $report->_data;
    $self->{_total_results} = @$all_data;
    return [
        splice @$all_data, $self->start_index, $self->items_per_page
    ];
}

sub _get_total_results {
    my $self = shift;
    return $self->{_total_results};
}

sub _entity_hash {
    my $self = shift;
    my $obj  = shift;

    my ($username, $count, $last_view) = @$obj;
    my $user = Socialtext::User->Resolve($username);
    return undef unless $user;

    # ASS-U-ME that if they can view the same page as you, you
    # can see their profile.
    my $user_id = $user->user_id;
    return {
        title          => $user->guess_real_name,
        uri            => "/st/profile/$user_id",
        is_person      => 1,
        user_id        => $user_id,
        count          => $count,
        context_title  => $user->primary_account->name,
        last_view      => $last_view,
    };
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
