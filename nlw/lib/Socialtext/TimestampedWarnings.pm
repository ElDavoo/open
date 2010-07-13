package Socialtext::TimestampedWarnings;
use warnings;
use strict;
use POSIX qw/strftime/;
our $FORMAT = '[%FT%T%z] ';
sub import {
    $SIG{__WARN__} = sub {
        my $msg = join($,||'',@_);
        my $ts = strftime($FORMAT, localtime);
        $msg =~ s/^/$ts/mg;
        CORE::warn($msg);
    };
}
1;
__END__

=head1 NAME

Socialtext::TimestampedWarnings

=head1 SYNOPSIS

    #!/usr/bin/perl
    use Socialtext::TimestampedWarnings;
    warn "oh shi...";
    warn "mul","ti","ple"," args";
    warn "with\nembedded\nnewlines\n";

=head1 DESCRIPTION

Sets C<$SIG{__WARN__}> to prepend each line with a timestamp.  The format can
be changed by altering $Socialtext::TimestampedWarnings::FORMAT (which is
input to POSIX::strftime).

=head1 COPYRIGHT

Copyright (c) 2010 Socialtext Inc., all rights reserved.

=cut
