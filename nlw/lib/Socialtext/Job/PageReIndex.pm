package Socialtext::Job::PageReIndex;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job::PageIndex';

override 'retry_delay' => sub {12 * 60 * 60};
override 'max_retries' => sub {14};

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
