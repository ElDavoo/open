package Socialtext::Template::Plugin::json;
# @COPYRIGHT@
use strict;
use warnings;
use Template::Plugin::Filter;
use Socialtext::JSON ();
use base 'Template::Plugin::Filter';

sub init {
    my $self = shift;
    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'json');
    return $self;
}

sub filter { return Socialtext::JSON::encode_json($_[1]); }

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
