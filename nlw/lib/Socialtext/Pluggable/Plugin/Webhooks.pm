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

    $self->add_hook("nlw.user.deactivate"   => \&deactivate_user);
    $self->add_hook("nlw.signal.new"        => \&signal_new);
    $self->add_hook("nlw.page.tags_added"   => \&pagetags_changed);
    $self->add_hook("nlw.page.tags_deleted" => \&pagetags_changed);
}

sub deactivate_user {
    my $self = shift;
    my $user = shift;

    # Delete all signals created by this user
    my $hooks = Socialtext::WebHook->Find(creator_id => $user->user_id);
    for my $h (@$hooks) {
        $h->delete;
    }
}

sub signal_new {
    my ($self, $signal) = @_;

    Socialtext::WebHook->Add_webhooks(
        class => 'signal.create',
        signal => $signal,
        payload_thunk => sub { 
            return {
                class => 'signal.create',
                actor => {
                    id             => $signal->user->user_id,
                    best_full_name => $signal->user->best_full_name,
                },
                at     => $signal->at,
                object => {
                    id          => $signal->signal_id,
                    create_time => $signal->at,
                    attachments => [ $signal->attachments_as_hashes ],
                    uri         => $signal->uri,
                    group_ids   => $signal->group_ids || [],
                    account_ids => $signal->account_ids || [],
                    annotations => $signal->annotations || [],
                    topics      => $signal->topics_as_hashes || [],
                    body        => $signal->body,
                    hash        => $signal->hash,
                    hidden      => $signal->is_hidden ? 1 : 0,
                    tags => [ map { $_->tag } @{ $signal->tags } ],
                    (
                        $signal->recipient_id
                        ? (recipient_id => $signal->recipient_id)
                        : (),
                    ),
                    (
                        $signal->in_reply_to ? (
                            in_reply_to => {
                                map { $_ => $signal->in_reply_to->$_ }
                                    qw(signal_id user_id uri)
                            }
                            )
                        : ()
                    ),
                },
            };
        },
        account_ids => $signal->account_ids,
        group_ids   => $signal->group_ids,
        annotations => $signal->annotations,
        tags        => $signal->tags,
        recipient_id => $signal->recipient_id,
        user_topics =>
            [ grep {defined} map { $_->user_id } $signal->user_topics ],
    );
}

sub pagetags_changed {
    my ($self, $page, %p) = @_;
    my $wksp = $p{workspace} or die "workspace is mandatory!";

    Socialtext::WebHook->Add_webhooks(
        class         => 'page.tag',
        account_ids   => [ $wksp->account->account_id ],
        workspace_id  => $wksp->workspace_id,
        tags          => $page->metadata->Category,
        page_id       => $page->id,
        payload_thunk => sub {
            my $editor = Socialtext::User->new(
                email_address => $page->metadata->From);
            my $editor_blob = {
                id             => $editor->user_id,
                best_full_name => $editor->best_full_name,
            };
            return {
                class  => 'page.tag',
                actor  => $editor_blob,
                at     => $page->metadata->Date,
                object => {
                    workspace => {
                        title => $wksp->title,
                        name  => $wksp->name,
                    },
                    id           => $page->id,
                    name         => $page->metadata->Subject,
                    uri          => $page->full_uri,
                    edit_summary => $page->edit_summary,
                    tags         => $page->metadata->Category,
                    tags_added   => $p{tags_added} || [],
                    tags_deleted => $p{tags_deleted} || [],
                    edit_time    => $page->metadata->Date,
                    type         => $page->metadata->Type,
                    editor       => $editor_blob,
                }
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
