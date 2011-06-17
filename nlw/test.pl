#!/usr/bin/env perl
use 5.12.0;
use Plack::Test;
use Term::ReadLine;

test_psgi
    app => do 'nlw.psgi',
    client => sub {
        my $cb = shift;
        my $do_req = sub {
            my $path = shift;
            $path ||= '/data/config';
            $path =~ s!^/+!/!;
            $path = "http://localhost$path" unless $path =~ m{://};
            my $req = HTTP::Request->new(GET => $path);
            my $res = $cb->($req);
            say $res->as_string;
        };

        if (@ARGV) {
            $do_req->($_) for @ARGV;
            return;
        }
        else {
            my $term = Term::ReadLine->new;
            while ( defined ($_ = $term->readline('>>> GET http://localhost/')) ) {
                chomp;
                $do_req->($_);
            }
        }
    };
