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
    hashmark => ['',''],
);

sub msg_markup_table { return \%markup }

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    if (my $cb = $self->{callbacks}{page_link}) {
        $cb->($ast);
    }
    return qq{"$ast->{text}" $ast->{workspace_id} [$ast->{page_id}]};
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    return $self->user_as_username( $ast );
}

sub msg_format_hashtag {
    my $self = shift;
    my $ast = shift;
    return "#$ast->{text}";
}

sub user_as_username {
    my $self = shift;
    my $ast  = shift;

    my $user = $self->_ast_to_user($ast);
    return '' unless $user;
    return $user->best_full_name;
}

sub markup_node {
    my $self = shift;
    my $is_end = shift;
    my $ast = shift;

    if ($ast->{type} eq 'a' and $is_end) {
        my $output = $self->msg_markup_table->{$ast->{type}}->[$is_end];
        if (($ast->{text}||'') eq $ast->{attributes}{href}) {
            $output =~ s/<HREF>//;
        }
        else {
            $output =~ s/HREF/$ast->{attributes}{href}/;
        }
        $self->{output} .= $output;
        return;
    }
    $self->SUPER::markup_node($is_end, $ast);
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
