package Socialtext::Challenger::Base;
# @COPYRIGHT@

use strict;
use warnings;
use Socialtext::BrowserDetect;

sub is_mobile_browser {
    return Socialtext::BrowserDetect::is_mobile() ? 1 : 0;
}

sub is_mobile_redirect {
    my $class = shift;
    my $url   = shift;
    if (defined $url) {
        $url =~ s{^https?://[^/]+}{};    # strip off scheme/host
        $url =~ s{^/}{};                 # strip off leading "/"
        $url =~ s{/.*$}{};               # strip off everything after first "/"
        return 1 if ($url eq 'lite');
        return 1 if ($url eq 'm');
    }
    return 0;
}

sub is_mobile {
    my $class = shift;
    return $class->is_mobile_browser(@_) || $class->is_mobile_redirect(@_);
}

sub clean_redirect_uri {
    my $class = shift;
    my $uri   = shift;

    # Don't allow for redirects to "/challenge"
    return if ($uri =~ m{^/challenge(?:[/\?].*)?$});

    # Don't allow for redirects to "/nlw/submit/log(in|out)"
    return if ($uri =~ m{^/nlw/submit/log});

    # Don't allow for empty redirects
    return if ($uri eq '');

    # URI looks ok
    return $uri;
}

1;

=head1 NAME

Socialtext::Challenger::Base - Base class for Authen Challengers

=head1 SYNOPSIS

  # derive your own challenger
  package Socialtext::Challenger::MyChallenger;

  use base qw(Socialtext::Challenger::Base);

  sub challenge {
  # ...
  }

  1;

=head1 DESCRIPTION

This module provides a base class for Authen Challengers, making several
helper methods available for use across Challengers.

=head1 METHODS

=over

=item $class->is_mobile_browser()

Returns true if the browser is considered to be a "mobile" device, returning
false otherwise.

=item $class->is_mobile_redirect($url)

Checks the given C<$url> to see if it looks like one of our "mobile" or "lite"
URLs.  Returns true if the URL appears to be for a mobile/lite page, returning
false otherwise.

=item $class->is_mobile($url)

Returns true if I<either> the browser or the URL appear to be mobile,
returning false otherwise.

=item $class->clean_redirect_uri($uri)

Cleans the provided C<$uri>, so that we avoid potential situations of
"redirecting back to the Challenger" (thus creating an infinite loop).

=back

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Socialtext, Inc., All Rights Reserved.

=cut
