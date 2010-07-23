# @COPYRIGHT@
package Socialtext::Attachments;
use strict;
use warnings;
use base 'Socialtext::Base';

use Carp ();
use Class::Field qw( field );
use File::Copy ();
use File::Path ();
use Socialtext::Attachment;
use Socialtext::ArchiveExtractor;
use Socialtext::Encode;
use Socialtext::File;
use Socialtext::Indexes;
use Socialtext::Page;
use Readonly;
use Socialtext::Validate qw( validate SCALAR_TYPE BOOLEAN_TYPE HANDLE_TYPE USER_TYPE );
use Socialtext::Timer qw/time_scope/;
use Socialtext::Cache;
use Memoize;
use Guard qw/scope_guard/;

sub class_id { 'attachments' }

{
    my $cache;
    sub cache {
        return $cache ||= Socialtext::Cache->cache('attachments');
    }
}

sub all {
    my $self = shift;
    my $t = time_scope 'all_attach';
    my %p = @_;
    my $page_id  = $p{page_id} || $self->hub->pages->current->id;
    my $no_index = $p{no_index};
    my $ws_id    = $self->hub->current_workspace->workspace_id;
    my $cache_key = join ':', $ws_id, $page_id;

    if (my $set = $self->cache->get($cache_key)) {
        return $set;
    }

    my @attachment_set;
    for my $entry ( @{ $self->_all_for_page($page_id, $no_index) } ) {
        my $attachment = $self->new_attachment(
            id      => $entry->{id},
            page_id => $page_id,
        )->load;
        next if $attachment->deleted;
        next unless -f $attachment->full_path; 

        push @attachment_set, $attachment;
    }

    $self->cache->set($cache_key => \@attachment_set);
    # Make sure our hub doesn't disappear
    $self->cache->set("hub:$cache_key" => $self->hub);

    return \@attachment_set;
}

sub attachment_exists {
    my $self = shift;
    my ($workspace, $page_id, $filename) = @_;

    my $old_ws = $self->hub->current_workspace;
    my $g = scope_guard { $self->hub->current_workspace($old_ws) };

    use Socialtext::Permission 'ST_READ_PERM';
    my $ws = Socialtext::Workspace->new(name => $workspace);
    return 0 unless $ws && $self->hub->authz->user_has_permission_for_workspace(
            user       => $self->hub->current_user,
            permission => ST_READ_PERM,
            workspace  => $ws,
        );

    $self->hub->current_workspace($ws);
    my $attachments = $self->all(page_id => $page_id);
    for my $att (@$attachments) {
        if ($att->filename eq lc($filename)) {
            return $att->exists || 0;
        }
    }
    return 0;
}

sub index {
    my $self = shift;
    $self->{index}
        ||= Socialtext::Indexes->new_for_class( $self->hub, $self->class_id );
}

sub new_attachment {
    my $self = shift;
    return Socialtext::Attachment->new(hub => $self->hub, @_);
}

{
    Readonly my $spec => {
        filename     => SCALAR_TYPE,
        fh           => HANDLE_TYPE,
        page_id      => SCALAR_TYPE( default => undef ),
        creator      => USER_TYPE,
        embed        => BOOLEAN_TYPE( default => 0 ),
        Content_type => SCALAR_TYPE( default => undef ),
        temporary    => SCALAR_TYPE( default => 0 ),
    };
    sub create {
        my $self = shift;
        my %args = validate( @_, $spec );

        $args{page_id} ||= $self->hub->pages->current->id;

        my $attachment = $self->new_attachment(%args);
        $attachment->save($args{fh});
        $attachment->store( user => $args{creator} );
        $attachment->inline( $args{page_id}, $args{creator} )
            if $args{embed};
        $self->cache->clear();
        return $attachment;
    }
}

sub index_generate {
    my $self = shift;
    my $hash = {};
    for my $page_id ( $self->hub->pages->all_ids ) {
        for my $attachment (
            @{ $self->all( page_id => $page_id, no_index => 1 ) } ) {
            next unless $attachment->id;
            $hash->{$page_id}{ $attachment->id } = $attachment->serialize;
        }
    }
    return $hash;
}

sub index_delete {
    my $self = shift;
    my ($hash, $attachment) = @_;
    my $page_id = $attachment->page_id;
    my $entry = $hash->{$page_id};
    if (keys %$entry <= 1) {
        delete $hash->{$page_id};
        return;
    }
    delete $entry->{$attachment->id};
    $hash->{$page_id} = $entry;
    return;
}

sub index_add {
    my $self = shift;
    my ($hash, $attachment) = @_;
    my $page_id = $attachment->page_id;
    my $entry = $hash->{$page_id} || {};
    $entry->{$attachment->id} = $attachment->serialize;
    $hash->{$page_id} = $entry;
    return;
}

sub all_serialized {
    my $self = shift;
    my $page_id = shift;

    my @all_serialized;
    for my $attachment (@{$self->all(page_id => $page_id)}) {
        push @all_serialized, $attachment->serialize;
    }
    return \@all_serialized;
}

sub all_in_workspace {
    my $self = shift;
    my @attachments;
    Socialtext::Timer->Continue('all_attach');
    my $hash = $self->index->read_only_hash;
    for my $page_id (keys %$hash) {
        my $p = Socialtext::Page->new( hub => $self->hub, id => $page_id );
        next unless $p->active;
        my $entry = $hash->{$page_id};
        $self->_add_attachment_from_index(\@attachments, $entry, $p);
    }
    Socialtext::Timer->Pause('all_attach');
    return \@attachments;
}

sub all_attachments_in_workspace {
    my $self = shift;
    return map {
        $self->new_attachment( id => $_->{id}, page_id => $_->{page_id}, )
            ->load
    } @{ $self->all_in_workspace() };
}

sub _all_for_page {
    my $self = shift;
    my $page_id  = shift;
    my $no_index = shift;
    my @attachments;

    if ($no_index) {
        my $directory = $self->plugin_directory . '/' . $page_id;

        Socialtext::File::ensure_directory($directory);

        for my $id ( Socialtext::File::all_directory_files($directory) ) {
            next unless $id =~ s/(.*)\.txt$/$1/;
            push @attachments, {id => $id};
        }
    }
    else {
        my $entry = $self->index->read($page_id);
        $self->_add_attachment_from_index( \@attachments, $entry );
    }
    return [ sort {$a->{id} cmp $b->{id}} @attachments ];
}

sub _add_attachment_from_index {
    my $self = shift;
    my $attachments_ref = shift;
    my $entry = shift;
    my $page = shift;

    push @$attachments_ref, map {
        {
            %$_,
            from => $self->_extract_username_or_email_address( $_->{from} ),
            page => $page,
        }
    } grep {
        -e $self->plugin_directory . '/' . $_->{page_id} . '/' . $_->{id};
    } values %$entry;
}

memoize('_extract_username_or_email_address', NORMALIZER => sub { $_[1] });
sub _extract_username_or_email_address {
    my $self = shift;
    my $from = shift;

    my $user;
    eval { $user = Socialtext::User->new( email_address => $_->{from} ) };
    warn $@ if $@;
    if ( $user ) {
        return $user->username;
    }
    return $from;
}

1;
