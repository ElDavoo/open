package Socialtext::Rest::JobsByClass;
# @COPYRIGHT@
use Moose;

use Socialtext::Exceptions;
use Socialtext::Jobs;
use Socialtext::Job;
use Socialtext::JSON qw/encode_json/;
use Socialtext::l10n qw(loc);
use POSIX qw/strftime/;

extends 'Socialtext::Rest::Jobs';

sub allowed_methods {'GET'}
sub collection_name { loc('All [_1] Jobs', $_[0]->jobclass) }

sub get_resource {
    my $self = shift;
    my $jobclass = $self->jobclass;
    my $funcname = $jobclass =~ /^Socialtext::Job::/ ? $jobclass :
        "Socialtext::Job::$jobclass";
    my @jobs = map { Socialtext::Job->new(job => $_)->to_hash } 
        Socialtext::Jobs->list_jobs(funcname => $funcname, limit => 1000);
    return \@jobs;
}

sub _entity_hash { }

sub resource_to_html {
    my ($self, $jobs) = @_;

    my @columns = qw(jobid uniqkey priority insert_time run_after grabbed_until coalesce);
    if ($self->rest->query->{'verbose'}) {
        $_->{arg} = YAML::Dump($_->{arg}) for @$jobs;
        push @columns, 'arg';
    }
    else {
        delete $_->{arg} for @$jobs;
    }

    for my $k (qw(insert_time run_after grabbed_until)) {
        $_->{$k} = $_->{$k} ? strftime('%F %T%z',localtime($_->{$k})) : ''
            for @$jobs;
    }

    return $self->template_render('data/job_list.html' => { 
        jobs => $jobs,
        columns => \@columns,
    });
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
