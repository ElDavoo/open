package Socialtext::Migration::Utils;
# @COPYRIGHT@
use strict;
use warnings;
use Socialtext::Schema;
use Socialtext::JobCreator;
use Socialtext::Workspace;
use List::MoreUtils qw(any);
use base 'Exporter'; 
our @EXPORT_OK = qw/socialtext_schema_version ensure_socialtext_schema
                    create_job_for_each_workspace create_job/;

sub socialtext_schema_version {
    my $schema = Socialtext::Schema->new;
    return $schema->current_version;
}

sub ensure_socialtext_schema {
    my $max_version = shift || die 'A maximum version number is mandatory';

    my $schema = Socialtext::Schema->new;
    return if $schema->current_version >= $max_version;

    print "Ensuring socialtext schema is at version $max_version\n";
    $schema->sync( to_version => $max_version );
}

sub create_job_for_each_workspace {
    my ($class, $prio, %opts) = @_;
    die 'A job class is mandatory' unless $class;
    $prio ||= 31;
    my $except = $opts{except} || [];

    my $job_class = 'Socialtext::Job::Upgrade::' . $class;

    my $all = Socialtext::Workspace->All;
    my $job_count = 0;
    while (my $ws = $all->next) {
        my $name = $ws->name;
        next if any { $_ eq $name } @$except;
        Socialtext::JobCreator->insert( $job_class,
            { 
                workspace_id => $ws->workspace_id,
                job => {
                    coalesce => $name,
                    ($prio ? (priority => $prio) : ()),
                }

            },
        );
        $job_count++;
    }

    # And add one more job to clean up global prefs
    Socialtext::JobCreator->insert( $job_class, { workspace_id => 0 } );
    $job_count++;

    print "Inserted $job_count $job_class jobs\n";
}

sub create_job {
    my $class = shift || die 'A job class is mandatory';
    my $prio  = shift || 31;
    my $job_class = 'Socialtext::Job::Upgrade::' . $class;

    Socialtext::JobCreator->insert( $job_class, {job => {coalesce => 'only'}} );

    print "Inserted $job_class job\n";
}

1;
