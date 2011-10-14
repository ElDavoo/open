package Socialtext::AccountLogo;
# @COPYRIGHT@
use Moose;
use File::Temp;
use Socialtext::Account;
use Socialtext::Image;
use Socialtext::File;
use Socialtext::Upload;
use namespace::clean -except => 'meta';

has 'account' => (
    is => 'ro', isa => 'Socialtext::Account',
    required => 1,
    weak_ref => 1,
    handles => { account_id => 'account_id', id => 'account_id' },
);

has 'logo' => (is => 'rw', isa => 'ScalarRef', lazy_build => 1);
sub _build_logo {
    my $self = shift;

    my $prefs = $self->account->prefs->all_prefs();
    my $img = Socialtext::Upload->Get(
        attachment_id => $prefs->{theme}{logo_image_id});


    my $blob;
    $img->_load_blob(\$blob);
    return \$blob;
}
__PACKAGE__->meta->make_immutable;
1;
