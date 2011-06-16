#!/usr/bin/env perl
use Plack::Test;
use Term::ReadLine;

test_psgi
    app => do 'app.psgi',
    client => sub {
        my $cb = shift;
        my $term = Term::ReadLine->new;
        my $OUT = $term->OUT || \*STDOUT;
        while ( defined ($_ = $term->readline('>>> GET http://localhost/')) ) {
            chomp;
            $_ ||= '/data/config';
            s!^/+!!;
            my $req = HTTP::Request->new(GET => "http://localhost/$_");
            my $res = $cb->($req);
            $OUT->print($res->as_string);
        }
    };
