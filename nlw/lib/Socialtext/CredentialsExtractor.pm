# @COPYRIGHT@
package Socialtext::CredentialsExtractor;
use strict;
use warnings;

use Socialtext::AppConfig;
use Socialtext::MultiCursor;
use base qw( Socialtext::MultiPlugin );

sub base_package {
    return __PACKAGE__;
}

sub _drivers {
    my $class = shift;
    my $drivers = Socialtext::AppConfig->credentials_extractors();
    my @drivers = split /:/, $drivers;
    return @drivers;
}

sub ExtractCredentials {
    my $class = shift;

    return $class->_first('extract_credentials', @_);
}

1;

__END__

=head1 NAME

Socialtext::CredentialsExtractor - a pluggable mechanism for extracting
credentials from a Request

=head1 SYNOPSIS

  use Socialtext::CredentialsExtractor;

  my $username_or_id = Socialtext::CredentialsExtractor->ExtractCredentials(
    $request,
  );

  die "No creds, can't do anything" if !$credentials;

=head1 DESCRIPTION

This class provides a hook point for registering new means of gathering
credentials from a request object. 

=head1 METHODS

=head2 Socialtext::CredentialsExtractor->ExtractCredentials

Returns the first defined set of credentials it can.

Individual plugin classes are expected to implement a method called
'extract_credentials' which returns a scalar, either username or user_id.

=head2 base_package()

Base package underneath which all Credentials Extractor plugins are to be
found.

=head1 AUTHOR

Socialtext, Inc., <code@socialtext.com>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Socialtext, Inc., All Rights Reserved.

=cut
