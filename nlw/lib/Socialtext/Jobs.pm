package Socialtext::Jobs;
use strict;
use warnings;
use Socialtext::SQL qw/sql_execute get_dbh/;
use Socialtext::Schema;
use MooseX::Singleton;
use Module::Pluggable search_path => 'Socialtext::Job', sub_name => 'job_types',
                      require => 1;
use Data::ObjectDriver::Driver::DBI ();
use TheSchwartz;

__PACKAGE__->job_types(); # force load the plugins up front

has client => (
    is => 'ro',
    isa => 'TheSchwartz',
    lazy_build => 1,
);

sub work_asynchronously {
    my $self = shift;
    my $job_class = 'Socialtext::Job::' . (shift || die "Class is mandatory");
    $self->schwartz_run( insert => $job_class => @_ );
}

sub list_jobs {
    my $self = shift;
    my %args = @_;
    $args{funcname} = "Socialtext::Job::$args{funcname}"
        unless $args{funcname} =~ m/::/;
    $self->schwartz_run(list_jobs => \%args);
}

sub clear_jobs           { sql_execute('DELETE FROM job') }
sub find_job_for_workers { shift->schwartz_run(find_job_for_workers => @_) }
sub work_once            { shift->schwartz_run(work_once => @_) }

sub can_do               {
    my $self = shift;
    my $job_class = 'Socialtext::Job::' . (shift || die "Class is mandatory");
    $self->schwartz_run(can_do => $job_class);
}

sub _build_client {
    my $self = shift;

    # Use an extra DB connection for now until we sort out how to
    # re-use the same DBH as the main apache.

    my %params = Socialtext::Schema->connect_params();
    return TheSchwartz->new( 
        databases => [ { 
            dsn => "dbi:Pg:database=$params{db_name}",
            user => $params{user},
        } ],
        driver_cache_expiration => 300,
        verbose => $ENV{ST_JOBS_VERBOSE},
    );
}

sub schwartz_run {
    my $self = shift;
    my $func = shift;

    return $self->client->$func(@_);
}

__PACKAGE__->meta->make_immutable;
1;
