package Socialtext::Job::EmailPage;
# @COPYRIGHT@
use Moose;
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

sub do_work {
    my $self = shift;
    my $page = $self->page or return;
    my $ws = $self->workspace or return;
    my $hub = $self->hub;

    my $ws_id = $ws->workspace_id;

    $hub->log->info( "Emailing out " . $ws->name . "/" . $page->id );
 
    $page->send_as_email( %{ $self->arg->{email_args} });

    $self->completed;
}

__PACKAGE__->meta->make_immutable;
1;
