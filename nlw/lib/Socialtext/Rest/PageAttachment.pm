package Socialtext::Rest::PageAttachment;
# @COPYRIGHT@
use warnings;
use strict;
use base 'Socialtext::Rest::Attachment';
use IO::File;
use Socialtext::HTTP ':codes';
use Socialtext::l10n qw(system_locale);
use Socialtext::String ();

sub allowed_methods { 'GET' }
sub permission { +{ GET => 'read' } }

sub _get_attachment {
    my $self = shift;
    my $page_uri = $self->pname;
    my $filename = $self->filename;

    my $page_id =  Socialtext::String::title_to_id($page_uri);

    my $attachments = $self->hub->attachments->all(page_id => $page_id);
    my $latest;
    for my $attach (@$attachments) {
        my $fn = $attach->filename;
        next unless $fn eq $filename;

        next if $latest and $latest->timestampish > $attach->timestampish;
        $latest = $attach;
    }
    return $latest;
}



1;
