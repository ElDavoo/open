package Socialtext::Moose::UserAttribute;
# @COPYRIGHT@
use warnings;
use strict;
use Moose::Exporter ();

Moose::Exporter->setup_import_methods(
    $Moose::VERSION >= 0.89 # added with_meta
        ? (with_meta => ['has_user'])
        : (with_caller => ['has_user'])
);

sub has_user {
    my ($class_or_meta, $field, %args) = @_;
    use Carp ();
    local $SIG{__WARN__} = \&Carp::cluck; # make warnings here extra-noisy

    my $meta = ($Moose::VERSION >= 0.89) # added with_meta
        ? $class_or_meta
        : Moose::Util::find_meta($class_or_meta);

    # this method moved some time after 0.72.  Makes the added attributes
    # appear to be from where 'has_user' was invoked.
    my $definition_context = $Moose::VERSION > 0.72
        ? Moose::Util::_caller_info(1)
        : Moose::_caller_info(1);

    my $id_field = $field.'_id';
    my $writer = "_$id_field";
    my $builder = "_build_$field";

    my $required = delete $args{required} || 0;
    my $is = delete $args{is} || 'ro';
    my $maybe = delete $args{st_maybe} || 0;
    my $weak = delete $args{weak_ref} || 0;

    my $isa = $maybe ? 'Maybe[Socialtext::User]' : 'Socialtext::User';

    my %id_field_args = (
        definition_context => $definition_context,
        is => 'rw', isa => 'Int',
        writer => $writer,
        required => $required,
    );

    my %field_args = (
        %args, definition_context => $definition_context,
        is => $is, isa => $isa,
        lazy_build => 1, weak_ref => $weak,
        # update the id field when the object field updates
        trigger => sub { $_[0]->$writer($_[1]->user_id) }
    );

    if ($required) {
        # force the ID field to be in sync with the construction parameter
        $meta->add_around_method_modifier('BUILDARGS' => sub {
            my $code = shift;
            my $clazz = shift;
            my $p = ref $_[0] ? $_[0] : {@_};
            if ($p->{$field} && !$p->{$id_field}) {
                $p->{$id_field} = $p->{$field}->user_id;
            }
            return $code->($clazz,$p);
        });
    }

    my $builder_method = Moose::Meta::Method->wrap(
        name         => $builder,
        package_name => $meta->name,
        body         => sub { 
            Socialtext::User->new(user_id => $_[0]->$id_field);
        },
    );

    require Socialtext::User;
    $meta->add_attribute($field => %field_args);
    $meta->add_attribute($id_field => %id_field_args);
    $meta->add_method($builder => $builder_method);

    return;
}

1;

__END__

=head1 NAME

Socialtext::Moose::UserAttribute

=head1 SYNOPSIS

  use Socialtext::Moose::UserAttribute;
  has_user 'creator' => (is => 'ro', st_maybe => 1);

=head1 DESCRIPTION

Provides a has_user moose attribute declarator.

=cut
