package Socialtext::Plack;
# @COPYRIGHT@
use warnings;
use strict;

=head1 NAME

Socialtext::Plack - Socialtext's tools for using Plack

=head1 SYNOPSIS

    use Socialtext::Plack;
    my @server_opts = (debug => 1);
    Socialtext::Plack->Run($app,'CoroAnyEvent',@server_opts);

Searches C<@INC> for C<Socialtext/PSGI/$app.psgi>.  The second argument is the
L<Plack::Server> engine to use.  Subsequent arguements are passed to the
server instance by Plack (but may also be used by this class to load/wrap the
app with certain middleware).

The C<debug> opt will cause errors to be printed to STDERR, including access
log entries (issued by L<Plack::Middleware::AccessLog>).  Otherwise, a log
file called C<$app.log> will be written to the usual place for logs under
Socialtext (C</var/log> for appliances, C<~/.nlw/log> for dev-envs).

=cut

use Plack::Util;
use Plack::Loader;

use Socialtext::AppConfig;
use Socialtext::HTTP::Ports;

sub Run {
    my $class = shift;
    my $app_name = shift;
    my $server_type = shift;
    my %args = @_;

    die "Invalid app name" unless $app_name =~ /^[a-zA-Z0-9_-]+$/;

    unless ($args{debug}) {
        my $log_path = '/var/log';
        if ($0 !~ m#^/usr/s?bin/#) {
            require Socialtext::Paths;
            $log_path = Socialtext::Paths->log_directory()
        }

        no warnings 'once';
        open LOGFH, '>>', "$log_path/$app_name.log"
            or die "can't open $app_name log for writing";
        select LOGFH; $|=1;
        open STDERR, '>&LOGFH';
        select STDERR; $|=1;
        open STDOUT, '>&LOGFH';
        select STDOUT; $|=1;
    }

    $args{host} ||= '127.0.0.1';
    if (!$args{port} && $app_name eq 'json-proxy') {
        $args{port} = Socialtext::HTTP::Ports->json_proxy_port;
    }

    my $relative_app = "Socialtext/PSGI/$app_name.psgi";
    my $app;
    foreach my $path (@INC) {
        my $psgi = "$path/$relative_app";
        next unless (-e $psgi && -r _);
        $app = $psgi;
        last;
    }

    die "Unable to locate $relative_app, search path: ".join(':',@INC)
        unless $app;

    # Sequence from this point on should be roughly the same as in plackup
    # 1. load the PSGI app
    # 2. apply middleware
    # 3. load Plack::Server::
    # 4. run the server with the wrapped app (loops)
    # 5. terminate the process

    warn "Loading from $app...\n";
    my $handler = eval { Plack::Util::load_psgi($app) };
    die "Unable to load handler: $@" unless $handler;

    if ($args{debug}) {
        warn "wrapping with AccessLog middleware";
        require Plack::Middleware::AccessLog;
        $handler = Plack::Middleware::AccessLog->wrap($handler,
            logger => sub { print STDERR @_ });
    }

    my $server = Plack::Loader->load($server_type, %args);
    die "Unable to load server" unless $server;

    warn "Starting $app_name Server on host $args{host} port $args{port}...\n";
    eval { $server->run($handler) };
    warn "Plack server exception: $@" if $@;
    warn "$app_name Server done\n";
}

1;
