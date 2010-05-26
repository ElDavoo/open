package Socialtext::Moose::UserAttribute;
# @COPYRIGHT@
use warnings;
use strict;
use Moose::Exporter ();

Moose::Exporter->setup_import_methods(
    with_caller => ['has_user'],
);

sub has_user {
    my ($class, $field, %args) = @_;
    use Carp ();
    local $SIG{__WARN__} = \&Carp::cluck; # make warnings here extra-noisy
    my $meta = Class::MOP::Class->initialize($class);

    my $id_field = $field.'_id';
    my $required = delete $args{required} || 0;
    my $is = delete $args{is} || 'ro';
    my $maybe = delete $args{st_maybe} || 0;
    my $weak = delete $args{weak_ref} || 0;

    my $isa = 'Socialtext::User';
    $isa = "Maybe[$isa]" if $maybe;
    my $definition_context = Moose::_caller_info(1);

    my %id_field_args = (is => 'rw', isa => 'Int',
        definition_context => $definition_context,
        writer => "_$id_field",
        required => $required,
    );

    my %field_args = (%args,
        definition_context => $definition_context,
        is => $is, isa => $isa,
        lazy_build => 1, weak_ref => $weak);

    {
        my $meth = "_$id_field";
        $field_args{trigger} = sub { $_[0]->$meth($_[1]->user_id) };
    }

    if ($required) {
        Moose::around($class, 'BUILDARGS' => sub {
            my $code = shift;
            my $clazz = shift;
            my $p = {@_};
            if ($p->{$field} && !$p->{$id_field}) {
                $p->{$id_field} = $p->{$field}->user_id;
            }
            return $code->($clazz,$p);
        });
    }

    Moose::has($class, $field    => %field_args   );
    Moose::has($class, $id_field => %id_field_args);

    my $builder = sub { 
        require Socialtext::User;
        my $self = shift;
        Socialtext::User->new(user_id => $self->$id_field);
    };
    my $method = Moose::Meta::Method->wrap(
        name                 => "_build_$field",
        package_name         => $class,
        body                 => $builder,
    );
    $meta->add_method("_build_$field" => $method);
    return;
}

1;
