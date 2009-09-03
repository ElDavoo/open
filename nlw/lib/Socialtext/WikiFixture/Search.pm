package Socialtext::WikiFixture::Search;
# @COPYRIGHT@
use Socialtext::System qw/shell_run/;
use Test::More;
use Moose;

extends 'Socialtext::WikiFixture::SocialRest';

after 'init' => sub {
    shell_run('nlwctl -c stop');
    shell_run('ceq-rm .');
};

sub set_searcher {
    my $self = shift;
    my $searcher = shift;

    my $class = 'Socialtext::Search::' . $searcher . '::Factory';
    shell_run("st-config set search_factory_class $class");
}

1;
