package signatures;
use Method::Signatures;

method import {
    unshift @_, 'Method::Signatures';
    goto &Method::Signatures::import;
}

1;

__END__

=head1 NAME

signatures

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
