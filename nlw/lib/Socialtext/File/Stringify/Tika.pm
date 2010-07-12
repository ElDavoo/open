package Socialtext::File::Stringify::Tika;
# @COPYRIGHT@
use Moose;
use Socialtext::System;
use Socialtext::File::Stringify::Default;
use Socialtext::Log qw/st_log/;
use namespace::clean -except => 'meta';

sub to_string {
    my ($class, $file) = @_;
    my $text = 
        Socialtext::System::backtick('st-tika', $file);
    if (my $e = $@) {
        st_log->error("st-tika: $e\n");
        return Socialtext::File::Stringify::Default->to_string($file);
    }

    if ($text =~ /^\s*$/) {
        st_log->warning("No text found in file $file\n");
        return '';
    }

    return $text;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

Socialtext::File::Stringify::Tika - Tika stringification engine

=head1 SYNOPSIS

  use Socialtext::File::Stringify;
  ...
  $text = Socialtext::File::Stringify->to_string($filename);

=head1 DESCRIPTION

Stringification engine for MS Office documents, using "Tika".  Compatible with
Office 2007.

=cut
