package Socialtext::Template::Plugin::json_filter;
# @COPYRIGHT@
use strict;
use warnings;
use Template::Plugin::Filter;
use Socialtext::JSON ();
use Socialtext::Encode 'ensure_is_utf8';
use base 'Template::Plugin::Filter';

sub init {
    my $self = shift;
    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'json');
    return $self;
}

# {bz: 4826}: Our templates use Unicode-strings, so we need to decode the
# octets back into unicode strings to avoid mojibake.
sub filter { return ensure_is_utf8(Socialtext::JSON::encode_json($_[1])); }

1;
__END__

=head1 NAME

Socialtext::Template::Plugin::json - json tt2 filter

=head1 SYNOPSIS

    [% USE json %]
    ...
    [% "foo\n" | json %][%# outputs literally "foo\n" %]

=head1 DESCRIPTION

Runs the filter input through C<Socialtext::JSON::encode_json>.

=cut
