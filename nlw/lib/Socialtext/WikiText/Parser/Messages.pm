package Socialtext::WikiText::Parser::Messages;
# @COPYRIGHT@
use strict;
use warnings;

use base 'WikiText::Socialtext::Parser';

use Socialtext::String ();

my $reserved   = q{;/?:@&=+$,[]#};
my $mark       = q{-_.!~*'()};
my $unreserved = "A-Za-z0-9\Q$mark\E";
my $uric       = quotemeta($reserved) . $unreserved . "%";

sub create_grammar {
    my $self = shift;
    my $grammar = $self->SUPER::create_grammar();
    my $blocks = $grammar->{_all_blocks};
    @$blocks = ('line');
    my $phrases = $grammar->{_all_phrases};

    # For {bz: 3771}, ":-" and ";-" are not <del>-production rules anymore.
    $grammar->{del} = {
        match => re_huggy(q{\-}),
        phrases => $grammar->{_all_phrases},
    };

    # NOTE: if you add phrases here, be sure to update %markup in
    # ST::WT::Emitter::Canonicalize
    @$phrases = ('waflphrase', 'asis', 'a', 'b', 'i', 'del');
    $grammar->{line} = {
        match => qr/^(.*)$/s,
        phrases => $phrases,
        filter => sub {
            chomp;
            s/\n/ /g; # Turn all newlines into spaces
        }
    };

    my $url_scheme = qr{(?:http|https|ftp|irc|file):(?://)?};
    $grammar->{a}{match} = [
        qr{(?:"([^"]*)"\s*)? < ( $url_scheme [$uric ]+ ) >}x,
        qr{()( $url_scheme [$uric]+ )}x,
    ];

    $grammar->{asis}{filter} = sub {
        my $node = shift;
        $_ = $node->{1} . $node->{2};
    };

    return $grammar;
}

sub re_huggy {
    my $brace1 = shift;
    my $brace2 = shift || $brace1;
    my $ALPHANUM = '\p{Letter}\p{Number}\pM';

    # {bz: 3771}: Make ":-)" and ";-)" smileys non-huggy.
    my $PRE_ALPHANUM = $ALPHANUM;
    $PRE_ALPHANUM .= ';:' if $brace1 eq q{\-};

    qr/
        (?:^|(?<=[^{$PRE_ALPHANUM}$brace1]))$brace1(?=\S)(?!$brace2)
        (.*?)
        $brace2(?=[^{$ALPHANUM}$brace2]|\z)
    /x;
}

sub handle_waflphrase {
    my $self = shift;
    my $match = shift; 
    return unless $match->{type} eq 'waflphrase';
    my $length = $match->{end} - $match->{begin};
    if ($match->{2} eq 'link') {
        my $options = $match->{3};
        if ($options =~ /^\s*([\w\-]+)\s*\[(.*)\]\s*$/) {
            my ($workspace_id, $page_id) = ($1, $2);
            my $text = $match->{text} || $page_id;
            $page_id =
                Socialtext::String::title_to_display_id($page_id, 'no-escape');
            $self->{receiver}->insert({
                wafl_type => 'link',
                workspace_id => $workspace_id,
                page_id => $page_id,
                text => $text,
                wafl_string => $options,
                wafl_length => $length
            });
            return;
        }
    }
    elsif ($match->{2} eq 'user') {
        my $options = $match->{3};
        $self->{receiver}->insert({
            wafl_type   => 'user',
            user_string => $options,
            wafl_length => $length
        });
        return;
    }

    $self->unknown_wafl($match);
}

sub unknown_wafl {
    my $self = shift;
    my $match = shift; 
    my $func = $match->{2};
    my $args = $match->{3};
    my $output = "{$func";
    $output .= ": $args" if $args;
    $output .= '}';
    $self->{receiver}->insert({output => $output});
}

1;
