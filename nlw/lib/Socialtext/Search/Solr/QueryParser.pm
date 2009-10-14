# @COPYRIGHT@
package Socialtext::Search::Solr::QueryParser;
use Moose;

=head1 NAME

Socialtext::Search::Solr::QueryParser

=head1 SYNOPSIS

  my $qp = Socialtext::Search::QueryParser->new;
  my $query = $qp->parse($query_string);

=head1 DESCRIPTION

Pre-parse Solr specific query options.

=cut

extends 'Socialtext::Search::QueryParser';

sub _build_field_map {
    my $self = shift;
    return {
        name          => 'name_pf_t',
        first_name    => 'first_name_pf_s',
        given_name    => 'first_name_pf_s',
        last_name     => 'last_name_pf_s',
        family_name   => 'last_name_pf_s',
        email         => 'email_address_pf_s',
        email_address => 'email_address_pf_s',
        url           => 'personal_url_pf_h',
        facebook      => 'facebook_url_pf_h',
        linkedin      => 'linkedin_url_pf_h',
        (map { $_ => $_ . "_sn_pf_s" } 
            qw/aol yahoo gtalk skype twitter sametime/),
    };
}

sub _build_searchable_fields { 
    my $self = shift;
    [
        # Page / attachment fields:
        qw/title tag body w/,
        # Signal fields:
        qw/w doctype id creator body pvt dm_recip a reply_to mention
           link_page_key link_w link date created is_question creator_name/,
        # People fields: (keys AND values)
        %{ $self->field_map },
        qw/phone/,
    ]
}

around 'parse' => sub {
    my ( $orig, $self, $query_string, @opts ) = @_;

    $query_string = $orig->($self, $query_string, @opts);

    if ($query_string =~ m/\*/) {
        $query_string = "{!defType=lucene}$query_string";
    }
    return lc $query_string;
};

1;
