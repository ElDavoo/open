package Apache::Constants;
use 5.12.0;
use parent 'Exporter';
use HTTP::Status ();

our @EXPORT;
our %EXPORT_TAGS = (
    common => \@EXPORT,
    response => \@EXPORT,
);

my %synonyms = (
    FOUND => 'REDIRECT',
    UNAUTHORIZED => 'AUTH_REQUIRED',
);

for my $method (@{$HTTP::Status::EXPORT_TAGS{constants}}) {
    no strict 'refs';
    (my $code = $method) =~ s/^HTTP_//;
    my $value = &{"HTTP::Status::$method"}();
    *$code = sub { $value };
    push @EXPORT, $code;
    if (my $sym = $synonyms{$code}) {
        *$sym = sub { $value };
        push @EXPORT, $sym;
    }
}

1;
