package Socialtext::WikiFixture::Search;
# @COPYRIGHT@
use Socialtext::System qw/shell_run/;
use Socialtext::People::Search;
use Socialtext::AppConfig;
use Test::More;
use Moose;

extends 'Socialtext::WikiFixture::SocialRest';

after 'init' => sub {
    shell_run('nlwctl -c stop');
    shell_run('ceq-rm .');
};

sub set_searcher {
    my $self     = shift;
    my $searcher = shift;

    my $class  = 'Socialtext::Search::' . $searcher . '::Factory';
    my $config = Socialtext::AppConfig->new();
    $config->set( 'search_factory_class' => $class );
    $config->write();
}

sub search_people {
    my $self = shift;
    my $query = shift;
    my $num_results = shift;

    my $viewer = Socialtext::User->Resolve( $self->{http_username} );
    my $ppl = Socialtext::People::Search->Search(
        $query,
        viewer => $viewer,
    );

    is scalar(@$ppl), $num_results, "search '$query' results: $num_results";

}

1;
