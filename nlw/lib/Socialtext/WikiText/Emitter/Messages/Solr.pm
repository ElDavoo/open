package Socialtext::WikiText::Emitter::Messages::Solr;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::WikiText::Emitter::Messages::Canonicalize';
use Socialtext::l10n qw/loc/;
use Readonly;

Readonly my %markup => (
    asis => [ '', '' ],
    b    => [ '',  '' ],
    i    => [ '',  '' ],
    del  => [ '',  '' ],
    a    => [ '"',  '"<HREF>' ],
);

sub msg_markup_table { return \%markup }

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    return qq{"$ast->{text}" $ast->{workspace_id} [$ast->{page_id}]};
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    return $self->user_as_username( $ast );
}

sub user_as_username {
    my $self = shift;
    my $ast  = shift;

    my $user = $self->_ast_to_user($ast);
    return '' unless $user;
    return $user->best_full_name;
}

# Copied from Base.pm and modified to not emit the HREF if it matches the link
# text (which happens for canonicalized raw links)
sub _markup_node {
    my $self = shift;
    my $offset = shift;
    my $ast = shift;

    my $markup = $self->msg_markup_table;
    return unless exists $markup->{$ast->{type}};

    my $output = $markup->{$ast->{type}}->[$offset];
    if ($ast->{type} eq 'a') {
        if ($ast->{text} eq $ast->{attributes}{href}) {
            $output =~ s/\<HREF\>//;
        }
        else {
            $output =~ s/HREF/$ast->{attributes}{href}/;
        }
        if ($self->{callbacks}{href_link} and $offset == 0) {
            $self->{callbacks}{href_link}->($ast);
        }
    }
    $self->{output} .= $output;
}

1;

=head1 NAME

Socialtext::WikiText::Emitter::Messages::Solr

=head1 SYNOPSIS

    use Socialtext::WikiText::Emitter::Messages::Solr

    my $parser = Socialtext::WikiText::Parser::Messages->new(
        receiver => Socialtext::WikiText::Emitter::Messages::Solr->new(),
    );
    my $body = $parser->parse($signal->body);

=head1 DESCRIPTION

Emit messages that can be passed to Solr for indexing.

=cut
