package Apache::Cookie;
# @COPYRIGHT@
use strict;
use warnings;

our $DATA = {};

sub new {
    my ($class, $req, %opts) = @_;
    my $self = { %opts };
    bless $self, $class;
}

sub value {
    my $self = shift;
    return wantarray ? %{ $self->{value} } : $self->{value};
}

sub fetch {
    return $DATA;
}

1;
