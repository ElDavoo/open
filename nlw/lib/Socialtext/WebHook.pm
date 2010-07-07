# @COPYRIGHT@
package Socialtext::WebHook;
use Moose;
use Socialtext::Workspace;
use Socialtext::SQL qw/sql_execute sql_singlevalue/;
use Socialtext::SQL::Builder qw/sql_nextval/;
use Socialtext::Log qw/st_log/;
use Carp qw/croak/;
use Socialtext::Page;
use Socialtext::JSON qw/decode_json encode_json/;
use namespace::clean -except => 'meta';

has 'id'           => (is => 'ro', isa => 'Int', required => 1);
has 'creator_id'   => (is => 'ro', isa => 'Int', required => 1);
has 'class'        => (is => 'ro', isa => 'Str', required => 1);
has 'account_id'   => (is => 'ro', isa => 'Int');
has 'workspace_id' => (is => 'ro', isa => 'Int');
has 'details_blob' => (is => 'ro', isa => 'Str', default => '{}');
has 'url'          => (is => 'ro', isa => 'Str', required => 1);
has 'workspace' => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'account'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'creator'   => (is => 'ro', isa => 'Object',  lazy_build => 1);
has 'details'   => (is => 'ro', isa => 'HashRef', lazy_build => 1);

my %valid_classes = map { $_ => 1 }
    qw/page.create page.update page.tag page.watch page.delete
       attachment.create attachment.delete
       signal.create signal.delete
       person.create
      /;

sub _build_workspace {die 'not implemented yet!'}
sub _build_account   {die 'not implemented yet!'}
sub _build_creator   {die 'not implemented yet!'}

sub _build_details {
    my $self = shift;
    return decode_json( $self->details_blob );
}

sub to_hash {
    my $self = shift;
    return {
        map { $_ => $self->$_ }
          qw/id creator_id account_id workspace_id class details url/
    };
}

sub delete {
    my $self = shift;
    sql_execute(q{DELETE FROM webhook WHERE id = ?}, $self->id);
}

# Class Methods

sub ById {
    my $class = shift;
    my $id = shift or die "id is mandatory";

    my $sth = sql_execute(q{SELECT * FROM webhook WHERE id = ?}, $id);
    die "No webhook found with id '$id'" unless $sth->rows;

    my $rows = $sth->fetchall_arrayref({});
    return $class->_new_from_db($rows->[0]);
}

sub Find {
    my $class = shift;
    my %args  = @_;

    my (@bind, @where);
    for my $field (qw/class account_id workspace_id/) {
        if (my $val = $args{$field}) {
            push @where, "$field = ?";
            push @bind, $val;
        }
    }

    my $where = join ' AND ', @where;
    die "Your Find was too loose." unless $where;
    my $sth = sql_execute( "SELECT * FROM webhook WHERE $where", @bind );
    return $class->_rows_from_db($sth);
}

sub Clear {
    sql_execute(q{DELETE FROM webhook});
}

sub All {
    my $class = shift;

    my $sth = sql_execute(q{SELECT * FROM webhook ORDER BY id});
    return $class->_rows_from_db($sth);
}

sub _rows_from_db {
    my $class = shift;
    my $sth   = shift;

    my $results = $sth->fetchall_arrayref({});
    return [ map { $class->_new_from_db($_) } @$results ];
}

sub _new_from_db {
    my $class = shift;
    my $hashref = shift;

    for (qw/account_id workspace_id/) {
        delete $hashref->{$_} unless defined $hashref->{$_};
    }
    return $class->new($hashref);
}

sub Create {
    my $class = shift;
    my %args  = @_;

    die "'$args{class}' is not a valid webhook class.\n"
        unless $valid_classes{$args{class}};

    my $h = $class->new(
        %args,
        id => sql_nextval('webhook___webhook_id'),
    );
    sql_execute('INSERT INTO webhook VALUES (?,?,?,?,?,?,?)',
        $h->id,
        $h->creator_id,
        $h->class,
        ($h->account_id   ? $h->account_id   : undef ),
        ($h->workspace_id ? $h->workspace_id : undef ),
        $h->details_blob,
        $h->url,
    );
    return $h;
}

sub Add_webhooks {
    my $class = shift;
    my %p = @_;
    $p{account_ids} ||= [];

    eval {
        my $hooks = $class->Find( class => $p{class} );
        for my $h (@$hooks) {
            if (my $h_acct_id = $h->{account_id}) {
                my $hook_matches = 0;
                for my $s_id (@{ $p{account_ids} }) {
                    next unless $s_id == $h_acct_id;
                    $hook_matches++;
                    last;
                }
                next unless $hook_matches;
            }
            if (my $h_ws_id = $h->{workspace_id}) {
                next unless $p{workspace_id} == $h_ws_id;
            }
            if ($p{class} eq 'signal') {
                if (my $hanno = $h->details->{annotation}) {
                    next unless ref($hanno) eq 'ARRAY';
                    my $nmspc = $hanno->[0];
                    my $anno = $p{annotations};
                    next unless defined $anno->{$nmspc};
                    if (@$hanno > 1) {
                        my $key = $hanno->[1];
                        next unless defined $anno->{$nmspc}{$key};
                        if (@$hanno > 2) {
                            my $hval = $hanno->[2];
                            my $val = $anno->{$nmspc}{$key};
                            my $vals = ref($val) ? $val : [$val];
                            my $match = 0;
                            for my $v (@$vals) {
                                $match++ if $v eq $hval;
                            }
                            next unless $match;
                        }
                    }
                }
            }

            Socialtext::JobCreator->insert(
                'Socialtext::Job::WebHook' => {
                    hook => {
                        id => $h->id,
                        url => $h->url,
                    },
                    payload => $p{payload_thunk}->(),
                },
            );
        }
    };
    if ($@) {
        st_log->info("Error firing webhooks: '$@' " . ref($@));
    }
}

__PACKAGE__->meta->make_immutable;
1;
