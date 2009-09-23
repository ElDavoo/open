package Socialtext::Async::Syslog;
# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Async::Syslog - asynchronous syslog messages

=head1 SYNOPSIS

    use Socialtext::Log;
    use Socialtext::Async::Syslog;

    st_log(...); # runs async

=head1 DESCRIPTION

Unblocks Log::Dispatch as used by Socialtext.

=cut

use Coro;
use AnyEvent;
use Coro::AnyEvent ();
use Coro::AIO;
use Coro::Semaphore;
use Sys::Syslog ();
use Guard;
use Fcntl;
use Log::Dispatch::Syslog ();
use Log::Dispatch::File::Socialtext ();

no warnings 'redefine';

unless ($] eq '5.008007' || $Sys::Syslog::VERSION eq '0.09') {
    warn "CAUTION: ".__PACKAGE__." may not work with your version of perl!\n";
    warn "CAUTION: Please inspect how Sys::Syslog works to see if it's changed.\n";
}

*Sys::Syslog::_syslog_send_socket = \&send_to_syslog_aio;
*Sys::Syslog::_syslog_send_stream = \&send_to_syslog_aio;

sub send_to_syslog_aio {
    my $buf = shift;
    Coro::AnyEvent::writable $Sys::Syslog::{SYSLOG};
    return syswrite $Sys::Syslog::{SYSLOG}, $buf, length($buf);
}


my $orig_log_message = \&Log::Dispatch::Syslog::log_message;
*Log::Dispatch::Syslog::log_message = \&unblocked_syslog_message;

{
    my $mutex = Coro::Semaphore->new;
    sub unblocked_syslog_message {
        my @args = @_;
        async_pool {
            my $g;
            $g = $mutex->guard;
            $orig_log_message->(@args);
        }
    }
}

*Log::Dispatch::File::Socialtext::_open_file = \&dont_open_file;
*Log::Dispatch::File::Socialtext::log_message = \&aio_write_to_file;

sub dont_open_file {
    my $self = shift;
    $self->{fh} = undef;
}

{
    my $mutex = Coro::Semaphore->new;
    sub aio_write_to_file {
        my $self = shift;
        my %p = @_;
        async_pool {
            $self->{fh} = undef;
            my $g = $mutex->guard;

            my $flags = O_APPEND|O_CREAT|O_WRONLY;
            my $mode = $self->{permissions} || 0660;
            my $fh;
            $fh = aio_open($self->{filename}, $flags, $mode)
                or die "cannot open $self->{filename}: $!";
            scope_guard {aio_close $fh};

            if ($self->{permissions} && !$self->{chmodded}) {
                my $st = aio_chmod $self->{filename}, $self->{permissions};
                die "Cannot chmod $self->{filename} to $self->{permissions}: $!"
                    if ($st < 0);
                $self->{chmodded} = 1;
            }

            my $msg = $p{message};
            $msg = Encode::encode_utf8($msg) if Encode::is_utf8($msg);

            my $wrote = aio_write($fh, 0, length($msg), $msg, 0);
            die "Cannot syswrite to '$self->{filename}': $!" if $wrote <=0
        };
    }
}

1;
