package Socialtext::Pluggable::Plugin::FakePlugin;
# @COPYRIGHT@
use strict;
use warnings;

use base 'Socialtext::Pluggable::Plugin';
use Class::Field 'const';

sub register {
    my $class = shift;
}

sub is_hook_enabled { 1 }

use constant scope => 'account';

sub test_hooks {
    my ($class, %hooks) = @_;
    no strict 'refs';
    while (my ($name, $sub) = each %hooks) {
        (my $subname = $name) =~ s/\W/_/g;
        *{"${class}::${subname}"} = $sub;
        $class->add_hook($name => $subname);
    }
}

1;
