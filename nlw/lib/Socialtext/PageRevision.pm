package Socialtext::PageRevision;
use Moose;
use MooseX::StrictConstructor;
use Time::HiRes ();
use Carp qw/croak carp/;
use Moose::Util::TypeConstraints qw/enum/;
use Tie::IxHash;

use Socialtext::Moose::UserAttribute;
use Socialtext::MooseX::Types::Pg;
use Socialtext::MooseX::Types::UniStr;

use Socialtext::SQL qw/:exec :txn :time/;
use Socialtext::SQL::Builder qw/sql_nextval sql_insert/;
use Socialtext::Encode qw/ensure_is_utf8 ensure_ref_is_utf8/;
use Socialtext::String ();
use Socialtext::Workspace;
use Socialtext::Hub;

use namespace::clean -except => 'meta';

enum 'PageType' => qw(wiki spreadsheet);

has 'hub' => (is => 'rw', isa => 'Socialtext::Hub', weak_ref => 1);

has 'workspace_id' => (is => 'rw', isa => 'Int');
has 'page_id' => (is => 'rw', isa => 'Str');
*id = *page_id; # legacy code may use this alias
has 'revision_id' => (is => 'rw', isa => 'Int');

has 'revision_num' => (is => 'rw', isa => 'Int', default => 0);
has 'name' => (is => 'rw', isa => 'UniStr', coerce => 1);
has_user 'editor' => (is => 'rw');
has 'edit_time' => (is => 'rw', isa => 'Pg.DateTime', coerce => 1,
    default => sub { DateTime->from_epoch(epoch => Time::HiRes::time()) } );
has 'page_type' => (is => 'rw', isa => 'PageType', default => 'wiki');
has 'deleted' => (is => 'rw', isa => 'Bool');
has 'summary' => (is => 'rw', isa => 'UniStr', coerce => 1, default => '');
has 'edit_summary' => (is => 'rw', isa => 'UniStr', coerce => 1, default => '');
has 'locked' => (is => 'rw', isa => 'Bool');
has 'tags' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub {[]});
has 'tag_set' => (is => 'ro', isa => 'Tie::IxHash', lazy_build => 1);

has 'body_length' => (is => 'rw', isa => 'Int', default => 0);
has 'body_ref' => (is => 'rw', isa => 'ScalarRef', lazy_build => 1,
    trigger => sub { $_[0]->_body_modded($_[1],$_[2]) });
has 'body_modified' => (is => 'rw', isa => 'Bool');

has 'prev' => (
    is => 'rw', isa => 'Socialtext::PageRevision',
    predicate => 'has_prev', clearer => 'clear_prev',
    handles => {
        prev_revision_id  => 'revision_id',
        prev_revision_num => 'revision_num',
    },
);

# don't change this outside of this package!
has 'mutable' => (is => 'rw', isa => 'Bool',
    writer => '__mutable', init_arg => '__mutable');

use constant COLUMNS => qw(
    workspace_id page_id revision_id revision_num name editor_id edit_time
    page_type deleted summary edit_summary locked tags body_length
);
use constant COLUMNS_STR => join(', ',COLUMNS());
use constant SELECT_COLUMNS_STR => COLUMNS_STR.
    q{, edit_time AT TIME ZONE 'UTC' || 'Z' AS edit_time_utc};

sub Get {
    my $class = shift;
    my $p = ref($_[0]) ? $_[0] : {@_};
    
    croak "hub is required" unless $p->{hub};
    croak "revision_id is required" unless $p->{revision_id};
    my $ws_id = $p->{workspace_id}
        || $p->{hub}->current_workspace->workspace_id;
    my $page_id = $p->{page_id}
        || $p->{hub}->pages->current->id;

    my $sth = sql_execute(q{
        SELECT }.SELECT_COLUMNS_STR.q{
          FROM page_revision
         WHERE workspace_id = ? AND page_id = ? AND revision_id = ?
    }, $ws_id, $page_id, $p->{revision_id});

    croak "unknown revision for page" unless $sth->rows == 1;
    my $row = $sth->fetchrow_arrayref();
    $row->{edit_time} = delete $row->{edit_time_utc};
    my $rev = $class->new($row);
    $rev->hub($p->{hub});
    return $rev;
}

sub Blank {
    my $class = shift;
    my %p = ref($_[0]) ? %{$_[0]} : @_;

    croak "hub is required to make a new revision" unless $p{hub};
    my $name = $p{name} || delete $p{title};
    croak "name (a title) is required" unless $name;

    my $hub = $p{hub};
    $p{workspace_id} = $hub->current_workspace->workspace_id;
    $p{name} = $name;
    $p{page_id} = Socialtext::String::title_to_id($name);
    $p{revision_id} = $p{revision_num} = 0;
    $p{editor} = $hub->current_user;
    $p{editor_id} = $p{editor}->user_id;
    $p{__mutable} = 1;
    
    return Socialtext::PageRevision->new(\%p);
}

sub is_spreadsheet { $_[0]->page_type eq 'spreadsheet' }
sub is_wiki { $_[0]->page_type eq 'wiki' }

sub _build_body_ref {
    my $self = shift;
    my $blob = sql_singleblob(q{
        SELECT body FROM page_revision
         WHERE workspace_id = $1 AND page_id = $2 AND revision_id = $3
    }, $self->workspace_id, $self->page_id, $self->revision_id);
    Encode::_utf8_on($$blob); # it should always be in the db as utf8
    $self->body_length(length $$blob);
    return $blob;
}

sub _body_modded {
    my ($self, $newref, $oldref) = @_;
    $self->body_modified((defined($newref) || defined($oldref))? 1 : undef);
    if ($newref && defined $$newref) {
        $self->body_length(length $$newref);
    }
    return;
}

sub pkey {
    my $self = shift;
    return map { $self->$_ } qw(workspace_id page_id revision_id);
}

sub mutable_clone {
    my $self = shift;
    my $p = ref($_[0]) ? $_[0] : {@_};
    croak "PageRevision is already mutable" if $self->mutable;

    $p->{editor} //= $self->hub->current_user;

    my %clone_args = map { $_ => $self->$_ } qw(
        page_id workspace_id revision_num name page_type deleted
        locked
    );
    $clone_args{revision_id} = 0;
    $clone_args{revision_num}++;
    $clone_args{editor} = $p->{editor};
    $clone_args{editor_id} = $p->{editor}->user_id;
    $clone_args{tags} = [@{$self->tags}];

    if ($p->{copy_body}) {
        my $body = ${$self->body_ref};
        $clone_args{body_ref} = \$body;
        $clone_args{summary} = $self->summary if $self->summary;
        $clone_args{edit_summary} = $self->edit_summary if $self->edit_summary;
    }

    $clone_args{prev} = $self;
    $clone_args{hub} = $self->hub;
    $clone_args{__mutable} = 1;
    return Socialtext::PageRevision->new(\%clone_args);
}

sub _build_tag_set {
    my $self = shift;
    return Tie::IxHash->new(
        map { my $x = $_; lc(ensure_is_utf8($x)) => $x } @{$self->tags}
    );
}

sub add_tags {
    my $self = shift;
    my $add = ref($_[0]) ? $_[0] : [@_];
    croak "PageRevision isn't mutable" unless $self->mutable;
    my $set = $self->tag_set;
    my $tags = $self->tags;
    my @added;
    for my $tag (@$add) {
        my $lc_tag = lc(ensure_is_utf8($tag));
        next if $set->EXISTS($lc_tag);
        $set->Push($lc_tag => $tag);
        push @added, $tag;
    }
    @$tags = $set->Values();
    return \@added;
}

sub delete_tags {
    my $self = shift;
    my $del = ref($_[0]) ? $_[0] : [@_];
    croak "PageRevision isn't mutable" unless $self->mutable;
    my $set = $self->tag_set;
    my $tags = $self->tags;
    my @deleted;
    for my $tag (@$del) {
        my $lc_tag = lc(ensure_is_utf8($tag));
        my $was = $set->Delete($lc_tag);
        push @deleted, $was if defined $was;
    }
    @$tags = $set->Values();
    return \@deleted;
}

sub store {
    my $self = shift;
    croak "PageRevision isn't mutable" unless $self->mutable;

    my $name_check = Socialtext::String::title_to_id($self->name); 
    croak "Cannot change page name: requires a different page_id"
        unless $self->page_id eq $name_check;

    $self->edit_summary(Socialtext::String::trim($self->edit_summary));
    $self->summary(Socialtext::String::trim($self->summary));

    my %args = map { $_ => $self->$_ } Socialtext::PageRevision::COLUMNS();
    $args{$_} = $args{$_} ? 1 : 0 for qw(locked deleted);
    $args{edit_time} = sql_format_timestamptz($args{edit_time});

    my $body;
    if ($self->body_modified) {
        $body = $self->body_ref;
        $args{body_length} = length($body);
    }
    elsif (!$self->has_prev) {
        my $x = '';
        $self->body_ref(\$x);
        $body = $self->body_ref;
        $self->summary('');
        $args{body_length} = 0;
    }
    else {
        # reuse the previous revision's body, copying at the Pg-level
        $args{body_length} = -1;
    }

    sql_txn {
        $args{revision_id} ||= sql_nextval('page_revision_id_seq');
        $args{revision_num} ||= 1;

        sql_insert(page_revision => \%args);

        if ($body) {
            # copy blob from Perl
            sql_saveblob($body, q{
                UPDATE page_revision SET body = $1
                 WHERE workspace_id = $2 AND page_id = $3 AND revision_id = $4
            }, @args{qw(workspace_id page_id revision_id)});
        }
        else {
            # copy blob from Pg
            my $prev_id = $self->prev_revision_id;
            sql_execute(q{
                UPDATE page_revision
                  SET body = old_rev.body,
                      body_length = old_rev.body_length
                 FROM (
                     SELECT body, body_length
                       FROM page_revision
                      WHERE workspace_id = $1 AND page_id = $2
                        AND revision_id = $3
                 ) old_rev
                WHERE workspace_id = $1 AND page_id = $2
                  AND revision_id = $4
            }, @args{qw(workspace_id page_id)},
               $prev_id => $args{revision_id});
        }
    };

    $self->revision_id($args{revision_id});
    $self->revision_num($args{revision_num});
    $self->body_modified(0);
    $self->clear_tag_set;
    $self->__mutable(0);

    return $self;
}

__PACKAGE__->meta->make_immutable;
1;
