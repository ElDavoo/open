package Socialtext::Job::Upgrade::FixBrokenStringifiersForSignals;
# @COPYRIGHT@
use Moose;
use Socialtext::JobCreator;
use Socialtext::SQL qw(sql_execute);
use namespace::clean -except => 'meta';

extends 'Socialtext::Job';

override 'keep_exit_status_for' => sub { 86400 };

sub do_work {
    my $self = shift;

    my $sig_list = $self->_signal_ids();
    foreach my $signal_id (@{$sig_list}) {
        Socialtext::JobCreator->index_signal($signal_id, priority => 54);
    }

    $self->completed();
}

sub _signal_ids {
    my $self = shift;
    my $sth  = sql_execute( q{
        SELECT signal_id
          FROM signal_attachment
          JOIN attachment USING (attachment_id)
         WHERE attachment.filename ~* '\.(doc|xml)$'
           AND NOT attachment.is_temporary;
    } );

    my $rows = $sth->fetchall_arrayref();
    my @ids  = map { $_->[0] } @{$rows};
    return \@ids;
}

__PACKAGE__->meta->make_immutable;
1;

