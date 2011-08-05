package Socialtext::Rest::PageAnnotations;
# @COPYRIGHT@
use Moose;
use Socialtext::HTTP ':codes';
use Socialtext::JSON;
extends 'Socialtext::Rest::Entity';

$JSON::UTF8 = 1;

sub allowed_methods { 'GET', 'PUT' }

{
    no strict 'refs';
    no warnings 'redefine';
    *GET_text = Socialtext::Rest::Entity::_make_getter(
        \&Socialtext::Rest::resource_to_yaml, 'text/plain');
    *GET_yaml = Socialtext::Rest::Entity::_make_getter(
        \&Socialtext::Rest::resource_to_yaml, 'text/x-yaml');
    *GET_html = Socialtext::Rest::Entity::_make_getter(
        \&resource_to_html, 'text/html');
}

sub entity_name {
    'Annotations for ' . $_[0]->page->name;
}

sub PUT_json {
    my ( $self, $rest ) = @_;

    my $unable_to_edit = $self->page_locked_or_unauthorized();
    return $unable_to_edit if ($unable_to_edit);

    my $page = $self->page;
    my $new_rev = $page->edit_rev();
    my $content = $rest->getContent();
 
    eval {
        $new_rev->anno_blob($content);
    };
    if ($@) {
        $self->rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain',
        );
        return $@;
    }

    $page->store(
        user => $rest->user,
    );

    $rest->header(
        -status => HTTP_200_OK,
    );
    return '';
}

sub get_resource {
    my $self = shift;

    #TODO Need perms check
    my $page = $self->page;
    return $page->annotations;
}

sub resource_to_html {
    my ( $self, $resource ) = @_;

    my $name = $self->entity_name;
    my $body = '';
    foreach my $annotation (@$resource) {
        while (my ($type, $keyvals) = each %$annotation) {
            $body .= '<h2>' . $type . "</h2>\n";
            $body .= "<table>\n";
            my @keys = keys %$keyvals;
            for my $key (@keys) {
                my $val = $annotation->{$type}{$key};
                $body .= "<tr><td>$key</td><td>$val</td></tr>\n";
            }
            $body .= "</table>\n"
        }
    }
    return ( << "END_OF_HEADER" . $body . << "END_OF_TRAILER" );
<html>
<head>
<title>$name</title>
</head>
<body>
<h1>$name</h1>
END_OF_HEADER
</body>
</html>
END_OF_TRAILER
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
