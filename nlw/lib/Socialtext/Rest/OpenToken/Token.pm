package Socialtext::Rest::OpenToken::Token;
# @COPYRIGHT@

use Moose;

extends 'Socialtext::Rest::Entity';
with 'Socialtext::Rest::OpenToken';

{
    no strict 'refs';
    no warnings 'redefine';
    *GET_text = Socialtext::Rest::Entity::_make_getter(
        \&Socialtext::Rest::resource_to_yaml, 'text/plain',
    );
}

sub allowed_methods { 'GET' }

sub entity_name {
    my $self  = shift;
    my $token = $self->token;
    return 'Token for ' . $token->data->{subject};
}

has 'token' => (
    is         => 'ro',
    isa        => 'Crypt::OpenToken::Token',
    lazy_build => 1,
);
sub _build_token {
    my $self      = shift;
    my $token_str = $self->token_str;
    my $factory   = $self->factory;
    my $token     = eval { $factory->parse($token_str) };
    unless ($token) {
        die "Invalid or malformed token.\n";
    }
    return $token;
}

sub get_resource {
    my $self = shift;
    return $self->token->data;
}

sub if_authorized {
    my $self   = shift;
    my $method = shift;
    my $call   = shift;

    # You're only authorized to dump the contents of a token if:
    #   a)  you're a Business Admin,
    #   b)  you created the token, or
    #   c)  the token is for your username
    my $user  = $self->rest->user;
    my $token = eval { $self->token };

    return $self->not_authorized
        unless $user->is_business_admin
            or $self->_is_my_token($token);

    return $self->$call(@_);
}

sub _is_my_token {
    my $self     = shift;
    my $token    = shift;
    my $username = $self->rest->user->username;

    if ($token) {
        return 1 if ($username eq $token->data->{'subject'});
        return 1 if ($username eq $token->data->{'created-by'});
    }
    return 0;
}

1;
