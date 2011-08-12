package Socialtext::Rest::AccountTheme;
use Moose;
use Socialtext::Account;
use Socialtext::Theme;
use Socialtext::SASSy;
use Socialtext::HTTP qw(:codes);
use Socialtext::Permission qw(ST_ADMIN_PERM ST_READ_PERM);
use Socialtext::Upload;
use Socialtext::JSON qw(encode_json decode_json);
use File::Path qw(mkpath);
use Socialtext::Paths;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::SettingsTheme';

has 'account' => (is=>'ro', isa=>'Maybe[Socialtext::Account]', lazy_build=>1);
sub _build_account {
    my $self = shift;
    return Socialtext::Account->Resolve($self->acct)
}

sub GET_css {
    my $self = shift;
    my $rest = shift;

    return $self->if_valid_request($rest => sub {
        if ($self->account->skin_name ne 'starfish') {
            $rest->header(-status => HTTP_400_Bad_Request);
            return 'Account is not using the starfish skin';
        }

        $rest->header(-type=>'text/css');
        
        my $sass = Socialtext::SASSy->new(account => $self->account);
        $sass->render if $sass->needs_update;
        $rest->header(
            -status               => HTTP_200_OK,
            '-content-length'     => -s $sass->css_file || 0,
            -type                 => 'text/css',
            -pragma               => undef,
            '-cache-control'      => undef,
            'Content-Disposition' => q{filename="style.css"},
            '-X-Accel-Redirect'   => $sass->protected_uri('account.css'),
        );
    });
}

sub GET_sass {
    my $self = shift;
    my $rest = shift;

    return $self->if_valid_request($rest => sub {
        if ($self->account->skin_name ne 'starfish') {
            $rest->header(-status => HTTP_400_Bad_Request);
            return 'Account is not using the starfish skin';
        }

        $rest->header(-type=>'text/sass');
        
        my $sass = Socialtext::SASSy->new(account => $self->account);
        $sass->render if $sass->needs_update;
        $rest->header(
            -status               => HTTP_200_OK,
            '-content-length'     => -s $sass->sass_file || 0,
            -type                 => 'text/plain',
            -pragma               => undef,
            '-cache-control'      => undef,
            'Content-Disposition' => q{filename="style.sass.txt"},
            '-X-Accel-Redirect'   => $sass->protected_uri('account.sass'),
        );
    });
}

override '_build_prefs' => sub {
    my $self = shift;

    return $self->account->prefs;
};

override 'if_valid_request' => sub {
    my $self = shift;
    my $rest = shift;
    my $coderef = shift;

    return $self->no_resource('account') unless $self->account;

    my $permission = $rest->getRequestMethod eq 'GET'
        ? ST_READ_PERM
        : ST_ADMIN_PERM;

    return $self->not_authorized()
        unless $self->account->user_can(
            user=>$self->rest->user,
            permission=>$permission,
        );

    return $coderef->();
};

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 NAME

Socialtext::Rest::AccountTheme - Handler for Account Themes ReST calls

=head1 SYNOPSIS

    GET /data/accounts/:acct/theme
    PUT /data/accounts/:acct/theme
    GET /data/accounts/:acct/theme/images/:filename

=head1 DESCRIPTION

View and manipulate Account Theme settings.

=cut
