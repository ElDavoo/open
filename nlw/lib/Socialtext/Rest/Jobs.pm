package Socialtext::Rest::Jobs;
# @COPYRIGHT@
use warnings;
use strict;

use base 'Socialtext::Rest::Collection';

use Class::Field qw( const field );
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::Exceptions;
use Socialtext::Jobs;
use Socialtext::l10n qw(loc);
use POSIX qw/strftime/;

{
    no strict 'refs';
    *{__PACKAGE__.'::GET_yaml'} = Socialtext::Rest::Collection::_make_getter(
        \&Socialtext::Rest::resource_to_yaml, 'text/x-yaml');
    *{__PACKAGE__.'::GET_text'} = Socialtext::Rest::Collection::_make_getter(
        \&Socialtext::Rest::resource_to_yaml, 'text/plain');
}

sub allowed_methods {'GET'}
sub collection_name { loc('Jobs') }

field errors => [];

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    return $self->bad_method
        unless $self->allowed_methods =~ /\b\Q$method\E\b/;

    return $self->not_authorized
        unless ($self->user_can('is_business_admin'));

    return $self->$call(@_);
}

sub get_resource {
    my $self = shift;
    my $rest = shift;

    my $stat = Socialtext::Jobs->stat_jobs();

    unless ($ENV{NLW_DEV_MODE}) {
        delete $stat->{'Socialtext::Job::Test'};
    }

    my @job_stats;
    for my $type (keys %$stat) {
        next unless $type =~ m/^Socialtext::Job::(.+)/;
        my $shortname = $1;
        next if $shortname =~ m/^Test::/;
        push @job_stats, {name => $shortname, %{$stat->{$type}}}
    }

    @job_stats = sort {$a->{name} cmp $b->{name}} @job_stats;

    return \@job_stats;
}

sub resource_to_html {
    my ($self, $job_stats) = @_;

    # TODO: this block is View code in the Controller
    my @column_order;
    {
        @column_order
            = qw(name queued delayed grabbed num_ok last_ok num_fail last_fail
                 latest latest_nodelay);
        # append extra keys
        my %avail = map {$_=>1} keys %{ $job_stats->[0] };
        delete @avail{@column_order};
        push @column_order, sort keys %avail;
    }

    for my $k (qw(last_ok last_fail latest latest_nodelay)) {
        $_->{$k} = format_timestamp($_->{$k}) for @$job_stats;
    }

    return $self->template_render('data/job_stats.html' => { 
        job_stats => $job_stats,
        columns => \@column_order,
    });
}

sub format_timestamp {
    my $t = shift;
    return $t ? strftime('%m/%d %T', localtime($t)) : '';
}

1;
