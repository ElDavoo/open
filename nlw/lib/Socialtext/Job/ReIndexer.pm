package Socialtext::Job::ReIndexer;
use Moose::Role;

requires 'indexer';

override 'retry_delay' => sub {12 * 60 * 60};
override 'max_retries' => sub {14};

around '_build_indexer' => sub {
    my $orig = shift;
    my $indexer = $orig->(@_);
    $indexer->always_commit(0);
    return $indexer;
};

no Moose::Role;
1;
__END__

=head1 NAME

Socialtext::Job::ReIndexer - (Re-)index things in the background

=head1 SYNOPSIS

  package Your::Job::Module;
  with 'Socialtext::Job::ReIndexer';

=head1 DESCRIPTION

Set the indexer to use solr auto-commit instead of committing after each
add.

=cut
