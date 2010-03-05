package Socialtext::Rest::Desktop;
# @COPYRIGHT@
use Moose;
use Socialtext::URI ();
use Socialtext::File 'get_contents_utf8';
use Socialtext::Helpers ();
use Socialtext::AppConfig ();
use Socialtext::HTTP ':codes';
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest';

our $ShareDir = Socialtext::AppConfig->code_base . '/desktop';
our $PrefersFlair = (
    $ENV{NLW_DEV_MODE}
        or (Socialtext::AppConfig->web_hostname eq 'www2.socialtext.net')
);

sub update_description_contents {
    my $self = shift;
    my $update_file = ( $PrefersFlair ? 'flair-update.xml' : 'update.xml' );
    return get_contents_utf8("$ShareDir/$update_file");
}

sub app_version {
    my $self = shift;
    my $xml = $self->update_description_contents;
    $xml =~ m{<version>(.+)</version>} or die "No version seen in Update XML file";
    return $1;
}

sub app_url {
    my $self = shift;
    my $app_name = ($PrefersFlair ? 'flairSignals' : 'SocialtextDesktop');

    return Socialtext::URI::uri(
        path => "/static/desktop/$app_name-".$self->app_version.'.air'
    );
}

sub GET {
    my ($self, $rest) = @_;

    unless (Socialtext::Helpers->desktop_update_enabled) {
        $rest->header( -status => HTTP_404_Not_Found );
        return '';
    }

    my $filename = $self->filename;

    if ($filename =~ /^(?:flair-)?badge(?:.html)?$/) {
        return $self->hub->template->process(
            ($PrefersFlair ? "desktop/flair-badge.html" : "desktop/badge.html"),
            app_url     => $self->app_url,
            app_version => $self->app_version,
            static_appliance_url => Socialtext::URI::uri(
                path => '/static/appliance'
            ),
            air_swf_url => Socialtext::URI::uri(
                path => '/static/desktop/air.swf'
            ),
        );
    }

    if ($filename =~ /^(?:flair-)?update(?:\.xml)?$/) {
        my $url = $self->app_url();

        my $xml = $self->update_description_contents;
        $xml =~ s{<url>(.*)</url>}{<url>$url</url>};

        $rest->header(
            -status               => HTTP_200_OK,
            -type                 => 'text/xml',
        );

        return $xml;
    }

    $rest->header( -status => HTTP_404_Not_Found );
    return '';
}

no Moose;
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::Desktop - Desktop resource handler

=head1 SYNOPSIS

    GET /st/desktop/badge
    GET /st/desktop/update

=head1 DESCRIPTION

Get Desktop-related files.

=cut
