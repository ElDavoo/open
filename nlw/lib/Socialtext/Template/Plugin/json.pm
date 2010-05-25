package Socialtext::Template::Plugin::json;
# @COPYRIGHT@
use strict;
use warnings;

use Template::Plugin::Filter;
use Socialtext::JSON qw/encode_json/;
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter($self->{ _ARGS }->[0] || 'json');

    return $self;
}

sub filter {
    my ($self, $content, $args, $config) = @_;
    my $json = encode_json($content);
    $json =~ s/\n/\\n/g;
    return $json;
}

1;
