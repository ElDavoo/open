package Socialtext::Template::Plugin::minify;;
# @COPYRIGHT@
use strict;
use Template::Plugin::Filter;
use JavaScript::Minifier::XS qw(minify);
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;

    $self->{ _DYNAMIC } = 1;

    # first arg can specify filter name
    $self->install_filter('minify');

    return $self;
}

sub filter {
    my ($self, $text) = @_;
    return minify($text);
}

1;
