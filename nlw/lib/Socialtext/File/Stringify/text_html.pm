# @COPYRIGHT@
package Socialtext::File::Stringify::text_html;
use warnings;
use strict;

use Socialtext::File::Stringify::Default;
use Socialtext::System ();
use Socialtext::Log qw/st_log/;

use HTML::Parser ();
use HTML::HeadParser ();
use HTML::Entities qw/decode_entities/;
use File::Temp qw/tempfile/;
use Encode ();
use Encode::Guess ();
use POSIX ();
use Guard;
use List::MoreUtils qw/firstidx/;

our $DEFAULT_OK = 1;

sub to_string {
    my ( $class, $buf_ref, $filename, $mime ) = @_;

    return if $class->stringify_html($buf_ref, $filename, $mime);
    if ($DEFAULT_OK) {
        st_log()->error($@) if $@;
        Socialtext::File::Stringify::Default->to_string(
            $buf_ref,$filename,$mime);
    }
    else {
        die $@ if $@;
    }
    return;
}

our $temp_fh;
our $temp_filename;
our $enc;

sub stringify_html {
    my ( $class, $buf_ref, $filename, $mime ) = @_;

    my ($charset) = ($mime =~ /charset=(.+);?/);

    my ($tfh, $tfilename) = tempfile(
        "/tmp/htmlstringify-$$-XXXXXX", CLEANUP => 1);
    local $temp_fh = $tfh;
    local $temp_filename = $tfilename;
    local $enc;

    binmode $temp_fh, ':utf8';

    my $pid = fork;
    die "can't fork html stringifier: $!" unless defined $pid;
    if ($pid) { # parent
        my $g = guard { kill -9, $pid; waitpid $pid, POSIX::WNOHANG(); };
        scope_guard { unlink "$temp_filename.err" };
        eval {
            local $SIG{ALRM} = sub { die 'Command Timeout' };
            alarm $Socialtext::System::TIMEOUT;
            waitpid $pid, 0; # wait until timeout or process exit
            alarm 0;
        };
        my $rv = $? >> 8;
        if ($rv) {
            $@ ||= "code $rv";
            my $err = do { local (@ARGV,$/) = "$temp_filename.err"; <> } || '';
            $@ = "HTML stringifier failed: $@ $err";
            $$buf_ref = '';
            return;
        }
        else {
            $g->cancel;
        }
    }
    else { # kid
        scope_guard { POSIX::_exit(1) }; # kill the process on exceptions

        open STDERR, '>', "$temp_filename.err";
        select STDERR; $|=1; select STDOUT;

        # XXX: this doesn't work when Test::Socialtext is used?!
        Socialtext::System::_vmem_limiter();

        _run_stringifier($filename, $charset);
        $temp_fh->flush or die "can't flush: $!";
        close $temp_fh or die "can't close: $!";
        POSIX::_exit(0);
    }

    # turn utf8 layer off so we can slurp with max efficiency!
    seek $temp_fh, 0, 0; # rewind
    binmode $temp_fh, ':mmap';
    $$buf_ref = do { local $/; <$temp_fh> };

    # And because it just wrote the file as utf8 so we can safely just switch
    # the flag on.
    Encode::_utf8_on($$buf_ref);

    return 1;
}

sub _run_stringifier {
    my ($filename, $charset) = @_;
    $charset = _detect_charset($filename) unless $charset;
    $enc = Encode::find_encoding($charset);
    my $p = HTML::Parser->new(
        ignore_elements => [qw(style script)],
        text_h => [\&_got_text, 'text'],
        start_h => [\&_got_start, 'tagname, @attr'],
        utf8_mode => 0,
        attr_encoded => 1, # do our own decoding of attr entities
        case_sensitive => 0, # lowercase tags and attrs
    );
    $p->parse_file($filename);
    return;
}

sub _detect_charset {
    my $filename = shift;
    my $hp = HTML::HeadParser->new();
    $hp->parse_file($filename);

    my $charset = $hp->header('Content-Type');
    if ($charset) {
        my ($cs) = ($charset =~ /charset=(.+);?/);
        $charset = $cs ? $cs : undef;
    }
    else {
        $charset = $hp->header('X-Meta-Charset');
    }

    # Check if the file seems to be one of the Unicode charsets.  UTF-16 foils
    # HTML::HeadParser.
    unless ($charset) {
        my $first_1k = do { local (@ARGV) = ($filename); local $/ = \1024; <> };
        Encode::Guess->set_suspects(
            qw/UTF-32LE UTF-16LE UTF-32BE UTF-16BE UTF-8/);
        my $guess = Encode::Guess->guess($first_1k);
        if (defined $guess) {
            $charset = $guess->name;
        }
    }

    $charset ||= 'UTF-8';
    return $charset;
}

sub _got_text {
    my $t = shift;
    $t = $enc->decode($t);
    decode_entities($t);
    $t =~ s/\s+/ /smg;
    return if ($t eq ' ' || $t eq '');
    # TODO: check byte count
    print $temp_fh $t, ' ';
}

sub _got_start {
    my $tag = shift;
    my $in;
    if ($tag eq 'a') {
        my $i = firstidx { $_ eq 'href' } @_;
        $in = $_[$i+1] if ($i >= 0 && $i <= $#_);
    }
    elsif ($tag eq 'meta') {
        my %attr = @_;
        if (my $name = $attr{name}) {
            $in = $attr{content}
                if ($name =~ /^(?:keywords|description|author)$/i);
        }
    }

    return unless defined $in;
    my $out = $enc->decode($in);
    decode_entities($out);
    # TODO: check byte count
    print $temp_fh $out, ' ';
}

1;
__END__

=head1 NAME

Socialtext::File::Stringify::text_html - Stringify HTML documents

=head1 CLASS METHODS

=over

=item to_string($filename)

Extracts the stringified content from C<$filename>, an HTML document.

=back

=head1 AUTHOR

Socialtext, Inc. C<< <code@socialtext.com> >>

=head1 COPYRIGHT

Copyright 2006-2010 Socialtext, Inc., all rights reserved.

=cut
