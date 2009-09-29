#!/usr/bin/perl
# @COPYRIGHT@
use warnings FATAL => 'all';
use strict;
use Coro;
use AnyEvent;
use Coro::AnyEvent;
use AnyEvent::Socket;
use Getopt::Long;
use Pod::Usage;

my $man = 0;
my $help = 0;
my $ram = 0; # in MiB
my $fds = 0; # in MiB
my $after = 60;
my $run_scgi = 1;

GetOptions(
    'help|?' => \$help,
    man      => \$man,
    'ram=i'  => \$ram,
    'fds=i'  => \$fds,
    'after=i' => \$after,
    'scgi!'  => \$run_scgi,
)
or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

use constant MiB => 1024 * 1024;

AnyEvent::detect;

our $death_clock;
if ($after) {
    $death_clock = AE::timer $after, 0, sub { print "death!\n"; exit 9; };
}

my $go_away = <<'EOM';
Status: 403 Go Away
Content-Type: text/plain
Connection: close

Go away!
EOM
$go_away =~ s/\n/\r\n/gsm;

my $port = $> + 6000;
our $server;
if ($run_scgi) {
    $server = tcp_server '127.0.0.1', $port, unblock_sub {
        my $fh = shift;
        my $handle = AnyEvent::Handle->new(fh => $fh);
        $handle->push_write($go_away);
        $handle->push_shutdown();
        # important to make a closure here:
        $handle->on_drain(sub { $handle->destroy });
        $handle->on_error(sub { $handle->destroy });
        return;
    };
}

our @sigs;
push @sigs, AE::signal 'HUP' => unblock_sub {
    print "Got HUP\n";
    undef $server if $server;
    Coro::AnyEvent::sleep 2;
    print "HUP done\n";
    exit 1;
};
push @sigs, AE::signal 'USR1' => sub { print "Got USR1\n" };
push @sigs, AE::signal 'USR2' => sub { print "Got USR2\n" };
push @sigs, AE::signal 'TERM' => sub { print "Got TERM\n"; exit 3; };
push @sigs, AE::signal 'INT'  => sub { print "Got INT\n";  exit 4; };

sub mem_hog {
    my $hog = 'z' x ($ram * MiB);
    AE::cv->recv; # wait forever
}

sub fd_hog {
    my @fh;
    for (1 .. $fds) {
        open my $fh, '>', '/dev/null';
        push @fh, $fh;
    }
    AE::cv->recv; # wait forever
}

async \&mem_hog if $ram;
async \&fd_hog if $fds;

print "waiting\n";
AE::cv->recv; # wait forever

__END__

=head1 NAME

cranky.pl - an ornery daemon

=head1 SYNOPSIS

  cranky.pl
  cranky.pl --ram 512 --fds 256 --after 5 --scgi

Options:
  --help    brief help message
  --man     full documentation
  --ram     consume this much RAM (in MiB)
  --fds     open at least this many file descriptors
  --after   exit abruptly after this many seconds (Default: 5 seconds)
  --sgci    Run a scgi socket that always sends 403s (Default: on)

=head1 OPTIONS

=over 8

=item B<--ram> NNN

Consume this much RAM in MiB (C<2**20>).  Allocates a single scalar with this
many characters.

Default: 0

=item B<--fds> NNN

Open C</dev/null> this many times.

Default: 0

=item B<--after> NNN

Exit with code "9" after this many seconds.  Use 0 to disable.

Default: 5

=item B<--scgi> B<--no-scgi>

Turn on (or off) the scgi socket.  Listens on port C<< $> + 6000 >> (your user
ID plus 6000).

Default: on

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

The default invocation of cranky.pl will exit after 5 seconds with code 9.  During this time, it will listen on a TCP port of your user ID plus 6000.

=head2 Signals

All signals not explicitly ignored will cause the daemon to exit.

=over 8

=item SIGUSR1 SIGUSR2

Ignored.

=item SIGTERM

Daemon exits with code 3.

=item SIGINT

Daemon exits with code 4.

=item SIGHUP

Closes the SCGI socket (if started), waits 2 seconds, then exits with code 1.

=back

=cut
