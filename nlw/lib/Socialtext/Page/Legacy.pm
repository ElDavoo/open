# @COPYRIGHT@
package Socialtext::Page::Legacy;
use strict;
use warnings;

use Socialtext::Encode;
use Socialtext::File;
use Socialtext::Paths;
use Socialtext::PageMeta;
use Socialtext::Search::AbstractFactory;
use Socialtext::Timer qw/time_scope/;
use Socialtext::EmailSender::Factory;
use Socialtext::l10n qw(loc system_locale);
use Socialtext::WikiText::Parser;
use Socialtext::WikiText::Emitter::SearchSnippets;
use Socialtext::String;
use Socialtext::Events;
use Socialtext::SQL qw/:exec :txn get_dbh sql_parse_timestamptz/;
use Socialtext::SQL::Builder qw/sql_insert_many/;
use Socialtext::Permission 'ST_READ_PERM';

sub parse_headers {
    my $self = shift;
    my $headers = shift;
    my $metadata = {};
    for (split /\n/, $headers) {
        next unless /^(\w\S*):\s*(.*)$/;
        my ($attribute, $value) = ($1, $2);
        if (defined $metadata->{$attribute}) {
            $metadata->{$attribute} = [$metadata->{$attribute}]
              unless ref $metadata->{$attribute};
            push @{$metadata->{$attribute}}, $value;
        }
        else {
            $metadata->{$attribute} = $value;
        }
    }

    # Putting whacky whitespace in a page title can kill javascript on the
    # front-end. This fixes {bz: 3475}.
    if ($metadata->{Subject}) {
        $metadata->{Subject} =~ s/\s/ /g;
    }

    return $metadata;
}

sub read_and_decode_file {
    my $filename       = shift;
    my $return_content = shift;
    die "No such file $filename" unless -f $filename;
    die "File path contains '..', which is not allowed."
        if $filename =~ /\.\./;

    # Note: avoid using '<:raw' here, it sucks for performance
    open(my $fh, '<', $filename)
        or die "Can't open $filename: $!";
    binmode($fh); # will Encode bytes to characters later

    my $buffer;
    {
        # slurp in the header only:
        local $/ = "\n\n";
        $buffer = <$fh>;
    }

    if ($return_content) { 
        # slurp in the rest of the file:
        local $/ = undef;
        $buffer = <$fh> || '';
    }

    $buffer = Socialtext::Encode::noisy_decode(
            input => $buffer,
            blame => $filename
    );

    $buffer =~ s/\015\012/\n/g;
    $buffer =~ s/\015/\n/g;
    return $buffer;
}

1;

__END__

=head1 NAME

Socialtext::Page::Legacy - Code used for the old filesystem based page store.

=head1 SYNOPSIS

  Try not to use this.

=head1 DESCRIPTION

Old codes only used for importing old filesystem page store.

=cut
