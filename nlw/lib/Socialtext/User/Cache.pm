# @COPYRIGHT@
package Socialtext::User::Cache;
use strict;
use warnings;
use Socialtext::Cache;
use Socialtext::Cache::TokyoCabinet;

our $Enabled = 0;
our %stats = (
    fetch  => 0,
    store  => 0,
    remove => 0,
);

my $PrimaryKey = 'user_id';
my @OtherKeys = qw(email_address username driver_unique_id);
my @ValidKeys = ($PrimaryKey,@OtherKeys);
my %ValidKeys = map { $_ => 1 } @ValidKeys;

sub ucache {
    my $cache = $Socialtext::Cache::CACHES{'USERS'};
    if (!$cache) {
        $cache = Socialtext::Cache::TokyoCabinet->new(
            namespace => 'USERS',
            host => $ENV{HOME}.'/.nlw/run/tt-users.sock',
            port => 0,
        );
        $Socialtext::Cache::CACHES{'USERS'} = $cache;
    }
    return $cache;
}

sub Fetch {
    my ($class, $key, $val) = @_;
    return unless $Enabled;
    return unless $ValidKeys{$key};
    $stats{fetch}++;
    my $uc = ucache();
    if ($key ne 'user_id') {
        warn "GET $key:$val\n";
        my $id = $uc->get("$key:$val");
        return unless $id;
        $key = 'user_id';
        $val = $id;
    }
    use XXX;
    warn "GET user_id:$val\n";
    my $hom = WWW($uc->get("user_id:$val"));
    return unless $hom;
    $hom->{cached_at} = DateTime::Format::Pg->parse_timestamptz($hom->{cached_at});
    return $hom;
}

sub Store {
    my ($class, $key, $val, $homunculus) = @_;
    return unless $Enabled;
    return unless $ValidKeys{$key};

    # remove any old cache entries for the homunculus defined by the given
    # key/val pair
    my $old_homey = _resolve_homunculus($key, $val);
    if ($old_homey) {
        # localize the stats so that the "remove" action doesn't get counted
        local %stats = %stats;
        $class->Remove($old_homey);
    }

    # proactively cache the homunculus against all valid keys, so he can be
    # found quickly/easily again in the future
    if ($homunculus) {
        $stats{store}++;
        my $id = $homunculus->user_id;
        my $uc = ucache();
        my $dt = delete $homunculus->{cached_at};
        $homunculus->{cached_at} = DateTime::Format::Pg->format_timestamptz($dt);
        use XXX;
        warn "MSET\n";
        ucache()->mset(WWW({
            "user_id:$id" => $homunculus,
            map { $_.":".$homunculus->$_ => $id } @OtherKeys
        }));
        $homunculus->{cached_at} = $dt;
    }
}

sub Remove {
    my $class = shift;
    return unless $Enabled;

    # accept either "key=>val" pair to lookup homunculus, or the homunculus
    # directly.
    my $homunculus = _resolve_homunculus(@_);
    return unless $homunculus;

    $stats{remove}++;
    my $uc = ucache();
    use XXX;
    warn "MREMOVE\n";
    $uc->mremove(WWW({
        map { $_ => $homunculus->$_ } @ValidKeys
    }));
}

sub Clear {
    my ($class,$force) = @_;
    ucache()->clear($force);
}

sub ClearStats {
    map { $stats{$_} = 0 } keys %stats;
}

sub _resolve_homunculus {
    # if given a "key=>val" pair, use that to find the homunculus in the cache
    if (@_ > 1) {
        my ($key, $val) = @_;
        return unless $ValidKeys{$key};
        warn "GET $key:$val\n";
        return ucache()->get("$key:$val");
    }
    # only given one arg; must *be* the homunculus
    return $_[0];
}

1;
