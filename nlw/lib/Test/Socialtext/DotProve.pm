use 5.12.0;

use TAP::Parser::YAMLish::Reader ();
use TAP::Parser::YAMLish::Writer ();
use Carp qw(croak);

package Test::Socialtext::DotProve;
use parent qw(Exporter);
our @EXPORT_OK qw(load save);

#stolen frpm App::Prove::State and hacked up.
#because it uses its own YAML dialect :-(

sub save {
    my ($yaml, $store) = @_;

    my $writer = TAP::Parser::YAMLish::Writer->new;
    local *FH;
    open FH, ">", "$store" or croak "Can't write $store ($!)";
    $writer->write( $yaml, \*FH);
    close FH;
}

sub load {
    my $name = shift;
    my $reader = TAP::Parser::YAMLish::Reader->new;
    local *FH;
    open FH, "<$name" or croak "Can't read $name ($!)";

    # XXX this is temporary
    my $yaml = $reader->read(
        sub {
            my $line = <FH>;
            defined $line && chomp $line;
            return $line;
        }
    );

    close FH;
    return $yaml;
}
