package Socialtext::User::Restrictions::base;

use Moose::Role;
use Socialtext::Date;
use Socialtext::MooseX::Types::Pg;

requires 'restriction_type';

has 'user_id' => (
    is          => 'ro',
    isa         => 'Int',
    required    => 1,
);

has 'token' => (
    is       => 'ro',
    isa      => 'Str',
    writer   => '_set_token',
);

has 'expires_at' => (
    is       => 'ro',
    isa      => 'Pg.DateTime',
    writer   => '_set_expires_at',
    required => 1,
    coerce   => 1,
);

has 'workspace_id' => (
    is  => 'ro',
    isa => 'Maybe[Int]',
);

sub update {
    my $self  = shift;
    my $proto = shift;
    Socialtext::User::Restrictions->Update($self, $proto);
}

sub clear {
    my $self = shift;
    Socialtext::User::Restrictions->Delete($self);
}

sub has_expired {
    my $self       = shift;
    my $now        = Socialtext::Date->now;
    my $expires_at = $self->expires_at;
    return $expires_at < $now;
}

1;
