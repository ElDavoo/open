package methods;
use Method::Signatures::Simple;

method import {
    unshift @_, 'Method::Signatures::Simple';
    goto &Method::Signatures::Simple::import;
}

1;

__END__

=head1 NAME

methods - Provides method syntax

=head1 SYNOPSIS

    use methods;
    method foo ($x) {
        $self->bar($x);
    }

=head1 DESCRIPTION

This module uses L<Method::Signatures::Simple> to provide named and
anonymouse methods with parameters, except with a shorter module name.

=head1 SEE ALSO

L<invoker>, L<signatures>

=cut
