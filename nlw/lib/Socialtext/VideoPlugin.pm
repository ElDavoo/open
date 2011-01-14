package Socialtext::VideoPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';
use Class::Field qw(const);
use Socialtext::l10n 'loc';
use Socialtext::JSON qw/encode_json/;
use Socialtext::Formatter::Phrase ();

const class_id    => 'video';
const class_title => 'VideoPlugin';
const cgi_class   => 'Socialtext::VideoPlugin::CGI';

our %Services = (
    YouTube => {
        match => [
            qr{://youtu\.be/([-\w]+)}i,
            qr{://(?:www\.)?youtube\.com/.*?\bv=([-\w]{11,})}i,
            qr{://(?:www\.)?youtube\.com/user/.*\/([-\w]{11,})}i,
            qr{://(?:www\.)?youtube\.com/embed/([-\w]{11,})}i,
        ],
        url => "http://www.youtube.com/watch?v=__ID__",
        html => q{<iframe src='https://www.youtube.com/embed/__ID__?rel=0'
                          type='text/html'
                          width='__WIDTH__'
                          height='__HEIGHT+45__'
                          frameborder='0'></iframe>},
    },
    Vimeo => {
        match => [
            qr{://(?:www\.)?vimeo\.com/(\d+)}i,
            qr{://player\.vimeo\.com/video/(\d+)}i,
        ],
        url => "http://www.vimeo.com/__ID__",
        html => q{<iframe src='http://player.vimeo.com/video/__ID__'
                          type='text/html'
                          width='__WIDTH__'
                          height='__HEIGHT__'
                          frameborder='0'></iframe>},
    },
    GoogleVideo => {
        match => [
            qr{://video\.google\.com/.*\bdocid=([-\w]+)}i,
        ],
        url => "http://video.google.com/videoplay?docid=__ID__",
        html => q{<embed src='http://video.google.com/googleplayer.swf?docid=__ID__&fs=true'
                         style='width:__WIDTH__px;height:__HEIGHT+25__px'
                         allowFullScreen='true' allowScriptAccess='always'
                         type='application/x-shockwave-flash'></embed> },
    },
    SlideShare => {
        match => [
            qr{^(\w+://(?:www\.)?slideshare\.net/.*)$}i,
        ],
        url => "__ID__",
        html => q|
            <div id="__UNIQUE__"></div>
            <script>
                function __UNIQUE__ (data) {
                    if (!data.html) { return; }
                    var match = data.html.match(/(<embed.*?<\/embed>)/);
                    if (!match) { return; }
                    document.getElementById('__UNIQUE__').innerHTML = match[1].replace(
                        /\bwidth="\d+"/g, 'width="__WIDTH__"'
                    ).replace(
                        /\bheight="\d+"/g, 'height="__HEIGHT__"'
                    );
                }
            </script>
            <script src="http://www.slideshare.net/api/oembed/1?format=jsonp;callback=__UNIQUE__;url=__ID__"></script>
        |
    },
);

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'check_video_url');
    $registry->add(wafl => video => 'Socialtext::VideoPlugin::Wafl');
}

sub check_video_url {
    my $self = shift;
    my $url = $self->cgi->video_url;
    $self->hub->rest->header(-type => 'application/json; charset=UTF-8');

    unless ($url =~ Socialtext::Formatter::HyperLink->pattern_start) {
        return encode_json({ error => loc("[_1] is not a valid URL.", $url) });
    }

    for my $service (values %Services) {
        for my $re (@{$service->{match}}) {
            $url =~ $re or next;
            return encode_json({ ok => $url });
        }
    }

    return encode_json({
        error => loc(
            "[_1] is not hosted on any of our supported services ([_2]).",
            $url,
            join(', ', sort keys %Socialtext::VideoPlugin::Services)
        )
    });
}


################################################################################
package Socialtext::VideoPlugin::Wafl;

use base 'Socialtext::Formatter::WaflPhraseDiv';
use Class::Field qw( const );
use Socialtext::Formatter::Phrase ();

const wafl_id => 'video';
const wafl_reference_parse => qr/^\s*<?(@{[
    Socialtext::Formatter::HyperLink->pattern_start
]})>?\s*(?:size=(.+))?\s*$/;


sub html {
    my $self = shift;
    my ($url, $size) = $self->arguments =~ $self->wafl_reference_parse;

    my $aspect_ratio = 1080/1920;
    my $toolbar_height = 0;
    my $embed_html;

SERVICES:
    for my $service (values %Socialtext::VideoPlugin::Services) {
        for my $re (@{$service->{match}}) {
            $url =~ $re or next;
            my $id = $1;
            $embed_html = $service->{html};
            my $unique = "st_unique_".int(rand(10000));
            $embed_html =~ s/__UNIQUE__/$unique/g;
            $embed_html =~ s/__ID__/$id/g;
            $embed_html =~ s/\n\s+/ /g;
            last SERVICES;
        }
    }

    if (!$embed_html) {
        $self->syntax_error(loc(
            "Error: [_1] is not hosted on any of our supported services ([_2]).",
            $url,
            join(', ', sort keys %Socialtext::VideoPlugin::Services)
        ));
    }

    no warnings 'numeric';

    my $width = {
        small => 240,
        medium => 480,
        large => 640
    }->{$size || 'medium'} || int($size) || 480;

    if ($size and $size =~ /(\d+)x(\d+)/ and $2) {
        my $height = $2;
        $width = $1;
        if ($embed_html =~ s/__HEIGHT\+(\d+)__/$height/eg) {
            $height -= $1;
        }
        else {
            $embed_html =~ s/__HEIGHT__/$height/g;
        }
        $width ||= int($height / $aspect_ratio);
    }

    $width = 1080 if $width > 1080;
    $width = 100 if $width < 100;
    $embed_html =~ s/__WIDTH__/$width/g;

    my $default_height = int($width * $aspect_ratio);
    $embed_html =~ s/__HEIGHT\+(\d+)__/$default_height+$1/eg;
    $embed_html =~ s/__HEIGHT__/$default_height/g;

    return $embed_html;
}

package Socialtext::VideoPlugin::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'video_url';

1;
