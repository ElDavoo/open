package Socialtext::VideoPlugin;
use strict;
use warnings;

use base 'Socialtext::Plugin';
use Class::Field qw(const);
use Socialtext::l10n 'loc';
use Socialtext::JSON qw/encode_json decode_json/;
use Socialtext::Formatter::Phrase ();
use Socialtext::String ();
use List::Util qw/max min/;

const class_id    => 'video';
const class_title => 'VideoPlugin';
const cgi_class   => 'Socialtext::VideoPlugin::CGI';

our %Services = (
    YouTube => {
        match => [
            qr{://youtu\.be/([-\w]{11,})}i,
            qr{://(?:www\.)?youtube\.com/.*?\bv=([-\w]{11,})}i,
            qr{://(?:www\.)?youtube\.com/user/.*\/([-\w]{11,})}i,
            qr{://(?:www\.)?youtube\.com/embed/([-\w]{11,})}i,
        ],
        url => "http://www.youtube.com/watch?v=__ID__",
        #oembed => "http://api.embed.ly/1/oembed?format=json;url=__URL__",
        oembed => "http://www.youtube.com/oembed?format=json;url=__URL__",
        html => q{<iframe src='https://www.youtube.com/embed/__ID__?rel=0'
                          type='text/html'
                          width='__WIDTH__'
                          height='__HEIGHT__'
                          frameborder='0'></iframe>},
    },
    Vimeo => {
        match => [
            qr{://(?:www\.)?vimeo\.com/groups/.*/videos/(\d+)}i,
            qr{://(?:www\.)?vimeo\.com/(\d+)}i,
            qr{://player\.vimeo\.com/video/(\d+)}i,
        ],
        url => "http://www.vimeo.com/__ID__",
        #oembed => "http://vimeo.com/api/oembed.json?url=__URL__",
        oembed => "http://api.embed.ly/1/oembed?format=json;url=__URL__",
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
        oembed => "http://api.embed.ly/1/oembed?format=json;url=__URL__",
        html => q{<embed src='http://video.google.com/googleplayer.swf?docid=__ID__&fs=true'
                         style='width:__WIDTH__px;height:__HEIGHT__px'
                         allowFullScreen='true' allowScriptAccess='always'
                         type='application/x-shockwave-flash'></embed>},
    },
    SlideShare => {
        match => [
            qr{^(\w+://(?:www\.)?slideshare\.net/.*)$}i,
        ],
        url => "__ID__",
        oembed => "http://www.slideshare.net/api/oembed/1?format=json;url=__URL__",
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
        |,
        html => "__HTML__",
        html_filter => sub {
            my $html = shift;
            $html =~ s/<strong\b[^>]*>.*?<\/strong>//i;
            $html =~ s!(<embed\b[^>]*)>\s*</embed>!$1 />!i;
            return $html;
        }
    },
);

sub register {
    my $self = shift;
    my $registry = shift;
    $registry->add(action => 'check_video_url');
    $registry->add(wafl => video => 'Socialtext::VideoPlugin::Wafl');
}

sub get_oembed_data {
    my ($self, $url, $width, $height) = @_;

    unless ($url =~ Socialtext::Formatter::HyperLink->pattern_start) {
        return { error => loc("[_1] is not a valid URL.", $url) };
    }

    for my $service (values %Services) {
        for my $re (@{$service->{match}}) {
            $url =~ $re or next;

            my $id = $1;
            my $oembed_url = $service->{url};
            $oembed_url =~ s/__ID__/$id/g;

            my $escaped_url = Socialtext::String::uri_escape($oembed_url);
            my $oembed_api = $service->{oembed};
            $oembed_api =~ s/__URL__/$escaped_url/g;

            use Try::Tiny;
            use LWP::Simple;

            my $payload;

            try { $payload = decode_json( LWP::Simple::get($oembed_api) ) };

            if ($payload and $payload->{title} and $payload->{width} and $payload->{height} and $payload->{html}) {
                my $html = $service->{html};
                $html =~ s/__ID__/$id/g;
                $html =~ s/__URL__/$escaped_url/g;
                $html =~ s/__HTML__/$payload->{html}/g;
                if ($service->{html_filter}) {
                    $html = $service->{html_filter}->($html);
                }
                $html =~ s/\bwidth=["']?\d+["']?/width="__WIDTH__"/g;
                $html =~ s/\bheight=["']?\d+["']?/height="__HEIGHT__"/g;
                $html =~ s/\bwidth:\s*\d+/width: __WIDTH__/g;
                $html =~ s/\bheight:\s*\d+/height: __HEIGHT__/g;

                $payload->{html} = $html;

                $self->_do_normalize_size($payload, $width, $height);

                return $payload;
            }
            return { error => loc("Sorry, this URL does not appear to link to an embeddable video.") };
        }
    }

    return {
        error => loc(
            "[_1] is not hosted on any of our supported services ([_2]).",
            $url,
            join(', ', sort keys %Socialtext::VideoPlugin::Services)
        )
    };
}

sub _do_normalize_size {
    my ($self, $payload, $width, $height) = @_;
    my ($orig_width, $orig_height, $html) = @{$payload}{qw( width height html )};
    my $aspect_ratio = $orig_height / $orig_width;

    $width = int($width);
    $height = int($height);

    if ($width > 0) {
        $width = min(1080, max(100, $width));
        $height ||= int($width * $aspect_ratio);
    }

    if ($height > 0) {
        $height = min(1080, max(100, $height));
        $width ||= int($height / $aspect_ratio);
    }

    $width ||= $orig_width;
    $height ||= $orig_height;

    # Now check again just in case that the orig. size is too large/small
    $width = min(1080, max(100, $width));
    $height = min(1080, max(100, $height));

    $html =~ s/__WIDTH__/$width/g;
    $html =~ s/__HEIGHT__/$height/g;
    $html =~ s/\n\s*/ /g;

    @{$payload}{qw( width height html )} = ($width || $orig_width, $height || $orig_height, $html);

    return $payload;
}

sub check_video_url {
    my $self = shift;
    $self->hub->rest->header(-type => 'application/json; charset=UTF-8');
    return encode_json(
        $self->get_oembed_data($self->cgi->video_url, $self->cgi->width, $self->cgi->height)
    );
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

    no warnings 'numeric';
    my $width = {
        small => 240,
        medium => 480,
        large => 640,
        original => 0
    }->{$size || 'original'};
    
    $width = int($size) unless defined $width;

    my $height;
    if ($size and $size =~ /(\d+)x(\d+)/ and $2) {
        ($width, $height) = ($1, $2);
    }

    my $data = $self->hub->video->get_oembed_data($url, $width, $height);

    if ($data->{error}) {
        return $self->syntax_error($data->{error});
    }

    return $data->{html};
}

package Socialtext::VideoPlugin::CGI;

use base 'Socialtext::CGI';
use Socialtext::CGI qw( cgi );

cgi 'video_url';
cgi 'width';
cgi 'height';

1;
