package Socialtext::UserSet;
# @COPYRIGHT@
use Moose;
use Carp qw/croak/;
use Socialtext::User;
use Socialtext::SQL qw/get_dbh/;
use Socialtext::Timer qw/time_scope/;
use namespace::clean -except => 'meta';

has 'trace' => (is => 'rw', isa => 'Bool', default => undef);

has 'owner_id' => (is => 'rw', isa => 'Int');
has 'owner' => (
    is       => 'rw',
# would really like this to work, but it doesn't.
#     isa      => 'Socialtext::Workspace|Socialtext::Account|Socialtext::Group',
    isa => 'Object',
    weak_ref => 1
);

sub _object_role_method ($);

=head1 NAME

Socialtext::UserSet - Nested collections of users

=head1 SYNOPSIS

  my $us = Socialtext::UserSet->new;
  # include user-set 5 into user-set 6 with a member role
  $us->add_role(5,6,$member->role_id);
  ok $us->connected(5,6);
  ok $us->has_role(5,6,$member->role_id);

=head1 DESCRIPTION

Maintains a graph of memberships and its transitive closure to give a
fast-lookup table for role resolution.

A user-set is an abstraction for users, groups, workspaces and accounts.  With
the exception of users, user-sets can be nested in other user-sets with an
explicit role.  A user-set cannot be nested into itself.

A user is included in other user-sets using the user's ID number. We number
all other user-set containers with IDs that don't overlap with users.

=head1 METHODS

For the C<_object_role> variants below, the C<$y> parameter is replaced by
C<$self->owner_id>.

=over 4

=item add_role ($x,$y[,$role_id])

=item add_object_role ($x,[,$role_id])

Add this edge to the graph. Default C<$role_id> is 'member'.

Throws an exception if an edge is already present.

=cut

around 'add_role' => \&_modify_wrapper;
_object_role_method 'add_object_role';
sub add_role {
    my ($self, $dbh, $x, $y, $role_id) = @_;
    croak "Can't add things to users"
        if Socialtext::User->new(user_id => $y);

    $role_id ||= 'member';
    if ($role_id =~ /\D/) {
        $role_id = Socialtext::Role->new(name => $role_id)->role_id;
    }
    $self->_insert($dbh, $x, $y, $role_id);
}

=item remove_role ($x,$y)

=item remove_object_role ($x)

Remove this edge from the graph. 

Throws an exception if this edge doesn't exist.

=cut

around 'remove_role' => \&_modify_wrapper;
_object_role_method 'remove_object_role';
sub remove_role {
    my ($self, $dbh, $x, $y) = @_;
    $self->_delete($dbh, $x, $y);
}

=item update_role ($x,$y,$role_id)

=item update_object_role ($x,$role_id)

Update the role_id attached to this edge.  All paths containing this edge that need updating will also get updated.

Throws an exception if the edge doesn't exist.

=cut

around 'update_role' => \&_modify_wrapper;
_object_role_method 'update_object_role';
sub update_role {
    my ($self, $dbh, $x, $y, $role_id) = @_;
    die "role_id is required" unless $role_id;

    $self->_delete($dbh, $x, $y);
    $self->_insert($dbh, $x, $y, $role_id);
}

=item remove_set ($n)

Removes all edges/roles involving node $n.

=cut

around 'remove_set' => \&_modify_wrapper;
sub remove_set {
    my ($self, $dbh, $n) = @_;

    my $rows = $dbh->do(q{
        DELETE FROM user_set_include
        WHERE from_set_id = $1 OR into_set_id = $1
    }, {}, $n);
    die "node $n doesn't exist" unless $rows>0;

    $dbh->do(q{
        SELECT purge_user_set($1);
    }, {}, $n);
    return;
}


=item connected ($x,$y)

Asks "is $x connected to $y through at least one path?"

=cut

around 'connected' => \&_query_wrapper;
sub connected {
    my ($self, $dbh, $x, $y) = @_;
    my ($connected) = $dbh->selectrow_array(q{
        SELECT 1
        FROM user_set_include_tc
        WHERE from_set_id = $1 AND into_set_id = $2
        LIMIT 1
    }, {}, $x, $y);
    return $connected ? 1 : undef;
}

=item has_role ($x,$y,$role_id)

Asks "is $x connected to $y where the effective role_id is $role_id?"

=cut

around 'has_role' => \&_query_wrapper;
sub has_role {
    my ($self, $dbh, $x, $y, $role_id) = @_;
    confess "role_id is required" unless $role_id;
    if ($role_id =~ /\D/) {
        $role_id = Socialtext::Role->new(name => $role_id)->role_id;
    }
    my ($has_role) = $dbh->selectrow_array(q{
        SELECT 1
        FROM user_set_include_tc
        WHERE from_set_id = $1 AND into_set_id = $2 AND role_id = $3
        LIMIT 1
    }, {}, $x, $y, $role_id);
    return $has_role ? 1 : undef;
}

=item has_plugin ($n,$plugin)

Asks "does $n have OR is $n included in a set that has $plugin enabled?"

=cut

around 'has_plugin' => \&_query_wrapper;
sub has_plugin {
    my ($self, $dbh, $n, $plugin) = @_;
    confess "plugin is required" unless $plugin;
    my ($has_plugin) = $dbh->selectrow_array(q{
        SELECT 1
        FROM user_set_plugin_tc
        WHERE user_set_id = $1 AND plugin = $2
        LIMIT 1
    }, {}, $n, $plugin);
    return $has_plugin ? 1 : undef;
}

=back

=cut

###################################################

sub _insert {
    my ($self, $dbh, $x, $y, $role_id) = @_;

    my $t = time_scope('uset_insert');

    $dbh->do(q{
        INSERT INTO user_set_include
        (from_set_id,into_set_id,role_id) VALUES ($1,$2,$3)
    }, {}, $x, $y, $role_id);
    
    $dbh->do(q{
        CREATE TEMPORARY TABLE to_copy (
            new_start int,
            new_via int,
            new_end int,
            new_vlist integer[]
        ) ON COMMIT DROP;
    });

    # create the union of
    # 1) a path for (x,y)
    # 2) paths that start with y; prepend (x,y) to these paths
    # 3) paths that end with x; append (x,y) to these paths
    # 4) pairs of paths joined by (x,y); paths that can be merged

    $dbh->do(q#
        INSERT INTO to_copy

        SELECT
            $1::integer,
            $1::integer,
            $2::integer,
            $5::int[]

        UNION

        SELECT DISTINCT
            $1::integer AS new_start,
            via_set_id AS new_via,
            into_set_id AS new_end,
            $3::int[] + vlist
        FROM user_set_path
        WHERE from_set_id = $2::integer

        UNION

        SELECT DISTINCT
            from_set_id AS new_start,
            into_set_id AS new_via,
            $2::integer AS new_end,
            vlist + $4::int[]
        FROM user_set_path
        WHERE into_set_id = $1::integer

        UNION

        SELECT DISTINCT
            before.from_set_id,
            after.vlist[icount(after.vlist) - 1] AS new_via,
            after.into_set_id,
            before.vlist + after.vlist
        FROM user_set_path before, user_set_path after
        WHERE before.into_set_id = $1 AND after.from_set_id = $2
    #, {}, $x, $y, "{$x}", "{$y}", "{$x,$y}");

    # There should be no duplicated vertices in the vertex list for each path.
    # The exception is for "reflexive" paths in which case we allow for one
    # and only one duplicate.
    # This has the effect of "pruning" the maintenance table to reduce the
    # number of redundant paths that were generated 
    $dbh->do(q{
        INSERT INTO user_set_path
        SELECT
            new_start AS from_set_id,
            new_via AS via_set_id,
            new_end AS into_set_id,
            usi.role_id AS role_id,
            new_vlist AS vlist
        FROM (
            SELECT *
            FROM to_copy
            WHERE (
                new_start = new_end AND
                icount(new_vlist) - 1  = icount(uniq(sort(new_vlist)))
            )
            OR
            (
                icount(new_vlist) = icount(uniq(sort(new_vlist)))
            )
        ) cpy
        JOIN user_set_include usi ON (
            usi.from_set_id = cpy.new_via AND
            usi.into_set_id = cpy.new_end
        )
    });

}

sub _delete {
    my ($self, $dbh, $x, $y) = @_;

    my $rows = $dbh->do(q{
        DELETE FROM user_set_include
        WHERE from_set_id = $1 AND into_set_id = $2
    }, {}, $x, $y);

    die "edge $x,$y does not exist" unless $rows>0;

    # There must be a GiST index on "vlist" for this to be fast.
    # The "contains" operator ("@") only checks for presence of x and y.
    # So, re-check that the vertex list element after x is indeed y.
    # NOTE: this only works if we disallow reflexive (x==y) edges in the input
    # table.
    # Recall that pg arrays are 1-based, not 0-based like C or Perl.
    $dbh->do(q{
        DELETE FROM user_set_path
        WHERE vlist @ $1::int[]
          AND vlist[idx(vlist,$2) + 1] = $3
    }, {}, "{$x,$y}",$x,$y);

    return $rows+0;
}

sub _modify_wrapper {
    my $code = shift;
    my $self = shift;

    my $t = time_scope('uset_update');
    my $dbh = get_dbh();
    local $dbh->{RaiseError} = 1;
    local $dbh->{TraceLevel} = ($self->trace) ? 3 : $dbh->{TraceLevel};
    $dbh->begin_work;
    eval {
        $dbh->do(q{LOCK user_set_include,user_set_path IN SHARE MODE});
        $self->$code($dbh, @_);
        $dbh->commit;
    };
    if (my $e = $@) {
        local $@;
        eval { $dbh->rollback };
        warn "during rollback: $@" if $@;
        confess $e;
    }
    return;
}

sub _query_wrapper {
    my $code = shift;
    my $self = shift;

    my $t = time_scope('uset_query');
    confess "requires x and y parameters" unless (@_ >= 2);

    my $dbh = get_dbh();
    local $dbh->{RaiseError} = 1;
    local $dbh->{TraceLevel} = ($self->trace) ? 3 : $dbh->{TraceLevel};
    return $self->$code($dbh, @_);
}

sub _object_role_method ($) {
    my $func = shift;
    (my $call = $func) =~ s/_object//;
    __PACKAGE__->meta->add_method(
        $func => Moose::Meta::Method->wrap(
            sub {
                my ($self, $obj, $role_id) = @_;
                die "must have owner_id" unless $self->owner_id;
                $self->$call($obj->user_set_id => $self->owner_id, $role_id);
            },
            name         => $func,
            package_name => __PACKAGE__
        )
    );
}

__PACKAGE__->meta->make_immutable();
1;
