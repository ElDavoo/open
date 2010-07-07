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

    $self->add_hook("nlw.signal.new" =>
        sub { shift->_add_signalhook('signal.create', @_) });
    $self->add_hook("nlw.signal.hidden" =>
        sub { shift->_add_signalhook('signal.delete', @_) });
    $self->add_hook("nlw.signal.delete" =>
        sub { shift->_add_signalhook('signal.delete', @_) });

    $self->add_hook("nlw.page.create" => 
        sub { shift->_add_pagehook('page.create' => @_, action => 'create') });
    $self->add_hook("nlw.page.update" => 
        sub { shift->_add_pagehook('page.update' => @_) });
    $self->add_hook("nlw.page.watch" => 
        sub { shift->_add_pagehook('page.watch' => @_) });
    $self->add_hook("nlw.page.delete" => 
        sub { shift->_add_pagehook('page.delete' => @_, action => 'delete') });
    $self->add_hook("nlw.page.tags_added" =>
        sub { shift->_add_pagehook('page.tag' => @_, action => 'tag') });
    $self->add_hook("nlw.page.tags_deleted" =>
        sub { shift->_add_pagehook('page.tag' => @_, action => 'tag') });

    $self->add_hook('nlw.attachment.create' =>
        sub { shift->_add_attachmenthook('attachment.create', @_) });
    $self->add_hook('nlw.attachment.delete' =>
        sub { shift->_add_attachmenthook('attachment.delete', @_) });

    $self->add_hook('nlw.person.create' =>
        sub { shift->_add_personhook('person.create', @_, action => 'create')});
    $self->add_hook('nlw.person.update' =>
        sub { shift->_add_personhook('person.update', @_)});
}

sub _add_signalhook {
    my $self = shift;
    my $class = shift;
    my $signal = shift;

    Socialtext::WebHook->Add_webhooks(
        class => $class,
        payload_thunk => sub { $signal->as_hash },
        account_ids => $signal->account_ids,
        annotations => $signal->annotations,
    );
}

sub _add_pagehook {
    my $self  = shift;
    my $class = shift;
    my $page  = shift;
    my %p     = @_;
    my $wksp  = $self->hub->current_workspace;

    Socialtext::WebHook->Add_webhooks(
        class         => $class,
        account_ids   => [ $wksp->account->account_id ],
        workspace_id  => $wksp->workspace_id,
        payload_thunk => sub {
            my $editor = Socialtext::User->new(
                email_address => $page->metadata->From);
            return {
                tags_added   => $p{tags_added}   || [],
                tags_deleted => $p{tags_deleted} || [],
                action       => $p{action} || 'update',
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

sub _add_attachmenthook {
    my $self  = shift;
    my $class = shift;
    my $att   = shift;
    my $wksp  = $self->hub->current_workspace;

    Socialtext::WebHook->Add_webhooks(
        class         => $class,
        account_ids   => [ $wksp->account->account_id ],
        workspace_id  => $wksp->workspace_id,
        payload_thunk => sub {
            my $creator = $att->uploaded_by;
            return {
                workspace_title => $wksp->title,
                workspace_name  => $wksp->name,
                page_id         => $att->page_id,
                attachment_id   => $att->id,
                attachment_date => $att->Date,
                filename        => $att->filename,
                length          => $att->Content_Length,
                mime_type       => $att->mime_type,
                creator         => {
                    user_id => $creator->user_id,
                    bfn     => $creator->best_full_name,
                },
            };
        },
    );
}

sub _add_personhook {
    my $self  = shift;
    my $class = shift;
    my $user  = shift;
    my %p     = @_;

    Socialtext::WebHook->Add_webhooks(
        class         => $class,
        account_ids   => [ $user->primary_account_id ],
        payload_thunk => sub {
            return {
                user_id => $user->user_id,
                username => $user->username,
                best_full_name => $self->best_full_name,
                %p,
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
