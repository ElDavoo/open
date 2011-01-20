package Socialtext::Model::Page;
# @COPYRIGHT@
use strict;
use warnings;
use DateTime::Format::Pg;
use Socialtext::SQL qw/sql_execute/;
use Socialtext::Page;
use Socialtext::File;
use Socialtext::URI;
use Socialtext::AppConfig;
use Socialtext::Timer;
use Carp qw/croak/;
use base 'Socialtext::Page::Base';

=head1 Socialtext::Model::Page

This class provides the same API as Socialtext::Page, but tries to be
lightweight and fast.  Users shouldn't call new_from_row(), but should
instead be given objects via Socialtext::Model::Pages.

=cut

our $No_result_times = 0;

my $SCRIPT_NAME = Socialtext::AppConfig->script_name();

# Called only by Socialtext::Model::Pages
sub new_from_row {
    my $class = shift;
    my $db_row = shift;
    bless $db_row, $class;
    $db_row->{last_edit_time} = delete $db_row->{last_edit_time_utc};
    $db_row->{create_time} = delete $db_row->{create_time_utc};
    return $db_row;
}

# This is called by Socialtext::Query::Plugin::push_result
# to create a row suitable for display in a listview.
sub to_result {
    my $self = shift;

    Socialtext::Timer->Continue('model_to_result');
    my $user = $self->last_edited_by;

    my $result = {
        From     => $user->email_address,
        username => $user->username,
        Date     => "$self->{last_edit_time} GMT",
        ($No_result_times ? ()
            : (DateLocal => $self->datetime_for_user)),
        Subject  => $self->{name},
        Revision => $self->{current_revision_num},
        Summary  => $self->{summary},
        Type     => $self->{page_type},
        page_id  => $self->{page_id},
        create_time => $self->{create_time},
        ($No_result_times ? () 
            : (create_time_local => $self->createtime_for_user)),
        creator => $self->creator->username,
        page_uri => $self->uri,
        revision_count => $self->{revision_count},
        $self->{hub} && !$self->hub->current_workspace->workspace_id ? (
            workspace_title => $self->workspace->title,
            workspace_name => $self->workspace->name,
        ) : (),
        is_spreadsheet => $self->is_spreadsheet,
        edit_summary => $self->{edit_summary},
        Locked     => $self->{locked},
        ($No_result_times ? (page => $self) : ()),
    };
    Socialtext::Timer->Pause('model_to_result');

    return $result;
}

sub createtime_for_user {
    my $self = shift;
    my $t = $self->{create_time};
    if ($self->{hub}) {
        $t = $self->{hub}->timezone->date_local($t);
    }
    return $t;
}

sub datetime_for_user {
    my $self = shift;
    my $datetime = $self->{last_edit_time};
    if ($self->{hub}) {
        $datetime = $self->{hub}->timezone->date_local($datetime);
    }
    return $datetime;
}

sub title          { $_[0]->{name} }
sub id             { $_[0]->{page_id} }
sub uri            { $_[0]->{page_id} }
sub summary        { $_[0]->{summary} }
sub edit_summary   { $_[0]->{edit_summary} }
sub deleted        {   $_[0]->{deleted} }
sub active         { ! $_[0]->{deleted} }
sub last_edit_time { $_[0]->{last_edit_time} }
sub add_tag        { push @{ shift->{tags} }, @_ }
sub hub            { $_[0]->{hub} || die "No hub was given to the page object"}
sub is_spreadsheet { $_[0]->{page_type} eq 'spreadsheet' }
sub type           { $_[0]->{page_type} }
sub current_revision_num { $_[0]->{current_revision_num} }
sub revision_count { $_[0]->{revision_count} }
sub revision_id    { $_[0]->{current_revision_id} }
sub revision_num   { $_[0]->{current_revision_num} }
sub locked         { $_[0]->{locked} }

sub workspace_name  { $_[0]->{workspace_name} }
sub workspace_title { $_[0]->{workspace_title} }

sub tags {
    my $self = shift;
    unless ($self->{tags}) {
        die "tags not loaded, and lazy loading is not yet supported.";
    }
    return $self->{tags};
}

sub hash_representation {
    my $self = shift;

    my $editor = $self->last_edited_by;

    my $hash = {
        name           => $self->{name},
        uri            => $self->{page_id},
        page_id        => $self->{page_id},
        last_editor    => $editor->email_address,
        last_edit_time => "$self->{last_edit_time} GMT",
        revision_id    => $self->{current_revision_id},
        revision_num   => $self->{current_revision_num},
        revision_count => $self->{revision_count},
        workspace_name => $self->{workspace_name},
        workspace_title => $self->{workspace_title},
        type           => $self->{page_type},
        tags           => $self->{tags},
        page_uri       => $self->full_uri,
        modified_time  => $self->modified_time,
        locked         => $self->{locked},
    };
    return $hash;
}

sub modified_time {
    my $self = shift;
    return $self->{modified_time} ||= 
        DateTime::Format::Pg->parse_timestamptz($self->{last_edit_time})->epoch;
}


sub workspace {
    my $self = shift;
    return $self->{workspace} ||= Socialtext::Workspace->new(
        workspace_id => $self->{workspace_id},
    );
}

sub full_uri {
    my $self = shift;
    return Socialtext::URI::uri(
        path => "$self->{workspace_name}/",
    ) . "$SCRIPT_NAME?$self->{page_id}";
}

sub categories_sorted {
    my $self = shift;
    return sort {lc($a) cmp lc($b)} @{$self->{tags}};
}

sub last_edited_by {
    my $self = shift;
    return $self->{last_editor}
        ||= Socialtext::User->new( user_id => $self->{last_editor_id} );
}

sub creator {
    my $self = shift;
    return $self->{creator}
        ||= Socialtext::User->new( user_id => $self->{creator_id} );
}

# This is the on-disk directory pages are stored, nothing to do with
# Postgresql
sub database_directory {
    my $self = shift;
    return Socialtext::Paths::page_data_directory( $self->{workspace_name} );

}

sub store {
    die 'Socialtext::Model::Page is currently a READ ONLY object';
}

1;
