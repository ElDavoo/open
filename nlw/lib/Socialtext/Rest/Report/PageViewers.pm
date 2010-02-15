package Socialtext::Rest::Report::PageViewers;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON qw/encode_json/;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::ReportAdapter';

=head1 NAME

Socialtext::Rest::Report::PageViewers - Viewers of a given page

=head1 SYNOPSIS

  GET /data/workspaces/:ws/pages/:page_id/viewers

=head1 DESCRIPTION

Shows the people that viewed the given page recently.

=cut

override 'GET_json' => sub {
    my $self = shift;
    my $user = $self->rest->user;
    my $page = $self->page;

    my $report = eval { $self->adapter->_build_report(
        'ViewersByPage', {
            start_time  => 'now',
            duration    => '-3months',
            type        => 'raw',
            workspace   => $self->hub->current_workspace->name,
            page_id     => $page->id,
        }, $user,
    ) };
    return $self->error(400, 'Bad request', $@) if $@;
    return $self->not_authorized unless $report->is_viewable_by($user);

    my @users;
    eval { 
        my $data = $report->_data;
        use Data::Dumper;
        warn Dumper $data;
        # Clean up the data
        for my $row (@$data) {
            my ($username, $count) = @$row;

            my $user = Socialtext::User->Resolve($username);
            warn "no user $username" unless $user;
            next unless $user;

            # ASS-U-ME that if they can view the same page as you, you
            # can see their profile.
            my $user_id = $user->user_id;
            push @users, {
                title          => $user->guess_real_name,
                uri            => "/st/profile/$user_id",
                is_person      => 1,
                user_id        => $user_id,
                count          => $count,
                context_title  => $user->primary_account->name,
            };
        }
    };
    return $self->error(400, 'Bad request', $@) if $@;

    $self->rest->header(-type => 'application/json');
    return encode_json({
        rows => \@users,
    });
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
