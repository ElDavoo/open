package Socialtext::Pluggable::Plugin::Webhooks;
# @COPYRIGHT@
use warnings;
use strict;
use Socialtext::WebHook;
use base 'Socialtext::Pluggable::Plugin';

use constant scope => 'account';
use constant hidden => 1; # hidden to admins
use constant read_only => 0; # cannot be disabled/enabled in the control panel
use constant is_hook_enabled => 1;

sub register {
    my $self = shift;

    $self->add_hook("nlw.signal.new"        => \&signal_new);
    $self->add_hook("nlw.page.tags_added"   => \&pagetags_changed);
    $self->add_hook("nlw.page.tags_deleted" => \&pagetags_changed);
}

sub signal_new {
    my ($self, $signal) = @_;

    Socialtext::WebHook->Add_webhooks(
        class => 'signal.create',
        payload_thunk => sub { $signal->as_hash },
        account_ids => $signal->account_ids,
        group_ids   => $signal->group_ids,
        annotations => $signal->annotations,
        tags        => $signal->tags,
    );
}

sub pagetags_changed {
    my ($self, $page, %p) = @_;
    my $wksp = $self->hub->current_workspace;

    Socialtext::WebHook->Add_webhooks(
        class         => 'page.tag',
        account_ids   => [ $wksp->account->account_id ],
        workspace_id  => $wksp->workspace_id,
        payload_thunk => sub {
            my $editor = Socialtext::User->new(
                email_address => $page->metadata->From);
            return {
                tags_added   => $p{tags_added}   || [],
                tags_deleted => $p{tags_deleted} || [],
                action       => 'tag',
                workspace_title => $wksp->title,
                workspace_name  => $wksp->name,
                page_id         => $page->id,
                page_name       => $page->metadata->Subject,
                page_uri        => $page->full_uri,
                edit_summary    => $page->edit_summary,
                tags            => $page->metadata->Category,
                edit_time       => $page->metadata->Date,
                editor          => {
                    user_id => $editor->user_id,
                    bfn     => $editor->best_full_name,
                },
            };
        },
    );
}

1;
__END__

=head1 NAME

Socialtext::Pluggable::Plugin::Webhooks

=head1 SYNOPSIS

Uses NLW hooks to fire Webhooks.

=head1 DESCRIPTION

=cut
