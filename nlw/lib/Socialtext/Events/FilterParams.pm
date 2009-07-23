package Socialtext::Events::FilterParams;
# @COPYRIGHT@
use Moose;
use Carp qw/croak/;
use MooseX::StrictConstructor;
use Clone ();
use namespace::clean -except => 'meta';

use constant AutoFilterParam => 'Socialtext::Events::FilterParams::AutoFilterParam';
{
    package Socialtext::Events::FilterParams::AutoFilterParam;
    use Moose::Role;

    has 'sql_builder' => (
        is => 'ro', isa => 'Str|CodeRef', 
        predicate => 'has_sql_builder',
    );
    has 'negative' => (
        is => 'ro', isa => 'Bool'
    );
}

# one thing (defined or not) OR many things (defined)
sub bunch_of {
    my $T = shift;
    return "Maybe[$T]|ArrayRef[$T]";
}

sub has_param ($@) {
    my $name = shift;

    has $name => (
        is => 'rw',
        traits => [AutoFilterParam],
        predicate => "has_$name",
        clearer => "clear_$name",
        @_,
        negative => undef,
    );

    # also register the negative
    has "not_$name" => (
        is => 'rw',
        traits => [AutoFilterParam],
        predicate => "has_not_$name",
        clearer => "clear_not_$name",
        @_,
        negative => 1,
    );
}

has_param 'action'            => (isa => bunch_of('Str'));
has_param 'actor_id'          => (isa => bunch_of('Int'));
has_param 'person_id'         => (isa => bunch_of('Int'));
has_param 'page_id'           => (isa => bunch_of('Str'));
has_param 'page_workspace_id' => (isa => bunch_of('Int'));
has_param 'tag_name'          => (isa => bunch_of('Str'));
has_param 'account_id'        => (isa => bunch_of('Int'));

# TODO: coerce from "Any" => "Iso8601Str" these two attrs:
has_param 'before' => (isa => 'Str', sql_builder => '_sb_before');
has_param 'after'  => (isa => 'Str', sql_builder => '_sb_after');

# These params require special implementation so the caller should handle
# them.  SQLSource may have some hints.

has 'followed'  => (is => 'rw', isa => 'Bool');
has 'contributions'  => (is => 'rw', isa => 'Bool');

sub BUILDARGS {
    my $class = shift;
    my %p = (@_==1) ? %{+shift} : @_;
    my %opts = map { (/^(.+)!$/ ? "not_$1" : $_) => $p{$_} } keys %p;
    return $class->SUPER::BUILDARGS(\%opts);
}

sub clone {
    my $self = shift;
    return Clone::clone($self);
}

sub generate_standard_filter {
    my $self = shift;

    my @attrs = grep { $_->does(AutoFilterParam) }
        $self->meta->get_all_attributes;

    my @filter;
    for my $attr (@attrs) {
        push @filter, $self->_filter_for_attr($attr);
    }
    return \@filter;
}

sub generate_filter {
    my $self = shift;
    my $meta = $self->meta;

    my @filter;
    for my $field (@_) {
        my $attr = $meta->find_attribute_by_name($field);
        croak "unknown param '$field'" unless $attr;
        push @filter, $self->_filter_for_attr($attr);

        my $dual_field = "not_$field";
        my $dual_attr = $meta->find_attribute_by_name($dual_field);
        push @filter, $self->_filter_for_attr($dual_attr) if $dual_attr;
    }

    return \@filter;
}

sub _filter_for_attr {
    my $self = shift;
    my $attr = shift;

    croak "param '".$attr->name."' must be handled manually" 
        unless ($attr->does(AutoFilterParam));

    if ($attr->has_sql_builder) {
        my $sb = $attr->sql_builder;
        return  $self->$sb($attr);
    }
    return unless $attr->has_value($self);

    my $column = $attr->name;
    $column =~ s/^not_// if $attr->negative;

    my $val = $attr->get_value($self);
    my $op = ('ARRAY' eq ref($val))
        ? ($attr->negative ? '-not_in' : '-in')
        : ($attr->negative ? '<>'       : '=' );
        
    return $column => {$op => $val};
}

sub _sb_before {
    my $self = shift;
    return $self->_before_after('<',@_);
}

sub _sb_after {
    my $self = shift;
    return $self->_before_after('>',@_);
}

sub _before_after {
    my $self = shift;
    my $op = shift;
    my $attr = shift;
    my $val = $attr->get_value($self);
    return unless $val;
    return 'at' => \["$op ?::timestamptz", $val];
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Socialtext::Events::FilterParams - Encapsulate Event feed filter parameters.

=head1 DESCRIPTION

Encapsulate Event feed filter parameters.

=head1 SYNOPSIS

    use Socialtext::Events::FilterParams

    # look for events that have edit_start or edit_cancel, but not view, and
    # no tag_name.
    my $filter = Socialtext::Events::FilterParams->new(
        action     => [ qw/edit_start edit_cancel/ ],
        not_action => 'view',
        tag_name   => undef,
    );

    # generate input for SQL::Abstract
    my @where = $filter->generate_standard_filter();

    # or (where will contain not_action clauses as well)
    my @where = $filter->generate_filter(qw/action tag_name/);

=head1 SEE ALSO

C<SQL::Abstract>

