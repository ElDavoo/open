package Socialtext::Async::Syslog;
# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Async::Syslog - asynchronous syslog messages

=head1 SYNOPSIS

    use Socialtext::Log;
    use Socialtext::Async::Syslog;

    st_log(...); # no longer blocks!

=head1 DESCRIPTION

Unblocks Sys::Syslog by using L<Coro::AIO>.  Uses a queue to maintain
per-process message ordering.

=cut

use Coro;
use Coro::AIO;
use Coro::Channel;
use Sys::Syslog ();

unless ($] eq '5.008007' || $Sys::Syslog::VERSION eq '0.09') {
    warn "CAUTION: ".__PACKAGE__." may not work with your version of perl!\n";
    warn "CAUTION: Please inspect how Sys::Syslog works to see if it's changed.\n";
}

{
    no warnings 'redefine';
    *Sys::Syslog::_syslog_send_socket = \&send_to_syslog_aio;
    *Sys::Syslog::_syslog_send_stream = \&send_to_syslog_aio;
}

{
    my $log_q = Coro::Channel->new;
    sub send_to_syslog_aio {
        my $buf = shift;
        $log_q->put(\$buf);
        return length($buf); # pretend that it worked.
    }

    async {
        $Coro::current->{desc} = __PACKAGE__.' writer';
        while (1) {
            my $buf = $log_q->get;
            return unless $buf;
            eval {
                aio_write(\*Sys::Syslog::SYSLOG, 0, length($$buf), $$buf, 0);
            };
        }
    };
}

1;
