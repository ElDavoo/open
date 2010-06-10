package Socialtext::WikiText::Emitter::Messages::HTML;
# @COPYRIGHT@
use strict;
use warnings;
use base 'Socialtext::WikiText::Emitter::Messages::Base';
use Socialtext::l10n qw/loc/;
use Socialtext::Formatter::AbsoluteLinkDictionary;
use Readonly;

Readonly my %markup => (
    asis => [ '',                '' ],
    b    => [ '<b>',             '</b>' ],
    i    => [ '<i>',             '</i>' ],
    del  => [ '<del>',           '</del>' ],
    a    => [ '<a href="HREF">', '</a>' ],
);

sub link_dictionary {
    my $self = shift;
    $self->{callbacks}{link_dictionary} ||=
        Socialtext::Formatter::AbsoluteLinkDictionary->new;
    return $self->{callbacks}{link_dictionary};
}

sub msg_markup_table { return \%markup }

sub msg_format_link {
    my $self = shift;
    my $ast = shift;
    my $url = $self->link_dictionary->format_link(
        url_prefix => $self->{callbacks}{baseurl} || "",
        link => 'interwiki',
        workspace => $ast->{workspace_id},
        page_uri => $ast->{page_id},
    );
    return qq{<a href="$url">$ast->{text}</a>};
}

sub msg_format_hashtag {
    my $self = shift;
    my $ast = shift;
    my $url = $self->link_dictionary->format_link(
        url_prefix => $self->{callbacks}{baseurl} || "",
        link => 'signal_hashtag',
        hashtag => $ast->{text},
    );
    return qq{#<a href="$url">$ast->{text}</a>};
}

sub msg_format_user {
    my $self = shift;
    my $ast = shift;
    my $userid = $ast->{user_string};
    my $viewer = $self->{callbacks}{viewer};

    my $user = eval { Socialtext::User->Resolve($userid) };
    unless ($user) {
        return loc("Unknown Person");
    }

    if ($viewer && $user->profile_is_visible_to($viewer)) {
        my $url = $self->link_dictionary->format_link(
            url_prefix => $self->{callbacks}{baseurl} || "",
            link => 'people_profile',
            user_id => $user->user_id,
        );
        return qq{<a href="$url">} . $user->guess_real_name . '</a>';
    }
    else {
        return $user->guess_real_name;
    }
}

sub text_node {
    my $self = shift;
    my $text = shift;
    return unless defined $text;
    $text =~ s/\s{2,}/ /g;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $self->{output} .= $text;
}

1;

