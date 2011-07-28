package Socialtext::Rest::Themes;
use Moose;
use Socialtext::Theme;
use Socialtext::JSON qw(encode_json);
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Collection';

sub GET_themes {
    my $self = shift;
    my $rest = shift;

    return $self->not_authorized() if $self->rest->user->is_guest;

    my $hashes = [ map { $_->as_hash } @{Socialtext::Theme->All()} ];

    return encode_json($hashes);
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
