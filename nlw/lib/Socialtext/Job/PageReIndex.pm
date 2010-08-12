package Socialtext::Job::PageReIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job::PageIndex';
with 'Socialtext::ReIndexJob';

override unlink_cached_wikitext_linkers => sub {};

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Socialtext::Job::PageReIndex - do it again

=head1 SYNOPSIS

  use Socialtext::JobCreator;
  Socialtext::JobCreator->index_page(
    $page, $config,
    page_job_class => 'Socialtext::Job::PageReIndex',
    attachment_job_class => 'Socialtext::Job::AttachmentReIndex'
  );

=head1 DESCRIPTION

Exactly like PageIndex but with retries.

=cut
