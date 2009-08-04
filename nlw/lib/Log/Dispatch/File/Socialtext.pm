package Log::Dispatch::File::Socialtext;
use strict;
use warnings;
use base qw( Log::Dispatch::File );

sub log_message {
    my $self = shift;
    my %p = @_;

    my $fh;
    if ( $self->{close} )
    {
      	$self->_open_file;
	$fh = $self->{fh};
      	syswrite($fh, $p{message})
            or die "Cannot syswrite to '$self->{filename}': $!";

      	close $fh
            or die "Cannot close '$self->{filename}': $!";
    }
    else
    {
        $fh = $self->{fh};
        syswrite($fh, $p{message})
            or die "Cannot syswrite to '$self->{filename}': $!";
    }
}

1;

__END__

=head1 NAME

Log::Dispatch::File::Socialtext - use syswrite

=cut

