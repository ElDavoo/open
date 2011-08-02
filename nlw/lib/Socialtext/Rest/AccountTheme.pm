package Socialtext::Rest::AccountTheme;
use Moose;
use Socialtext::Theme;
use Socialtext::HTTP qw(:codes);
use Socialtext::Permission qw(ST_ADMIN_PERM ST_READ_PERM);
use Socialtext::Upload;
use Socialtext::JSON qw(encode_json decode_json);

extends 'Socialtext::Rest::Collection';

has 'account' => (is=>'ro', isa=>'Maybe[Socialtext::Account]', lazy_build=>1);
has 'upload' => (is=>'ro', isa=>'Maybe[Socialtext::Upload]', lazy_build=>1);

sub _build_account {
    my $self = shift;
    return Socialtext::Account->Resolve($self->acct)
}

sub _build_upload {
    my $self = shift;

    return unless $self->filename;

    my $img_name = $self->filename .'_image_id';
    my $prefs = $self->account->prefs->all_prefs;

    my $id = $prefs->{theme}{$img_name};
    return unless $id;

    return Socialtext::Upload->Get(attachment_id=>$id);
}

sub GET_theme {
    my $self = shift;
    my $rest = shift;

    return $self->no_resource('account') unless $self->account;

    return $self->not_authorized()
        unless $self->account->user_can(
            user => $self->rest->user,
            permission => ST_READ_PERM,
        );

    my $prefs = $self->account->prefs->all_prefs;

    $rest->header(-type => 'application/json');
    return encode_json($prefs->{theme});
}

sub PUT_theme {
    my $self = shift;
    my $rest = shift;
    my $user = $self->rest->user;

    return $self->no_resource('account') unless $self->account;

    return $self->not_authorized()
        unless $self->account->user_can(
            user => $user,
            permission => ST_ADMIN_PERM,
        );

    my $prefs = $self->account->prefs;
    my $current = $prefs->all_prefs->{theme};

    my $updates = eval { decode_json($rest->getContent()) };
    unless ($updates && Socialtext::Theme->ValidSettings($updates)) {
        $rest->header(-status => HTTP_400_Bad_Request);
        return;
    }

    for my $key qw(header_image_id background_image_id) {
        my $value = $updates->{$key};
        next unless $value;

        my $upload = Socialtext::Upload->Get(attachment_id=>$value);
        $upload->make_permanent(actor=>$user)
            if $upload->is_temporary();
    }
    
    my $settings = {%$current, %$updates};
    $prefs->save({theme=>$settings});

    $rest->header(-type => 'text/plain', -status => HTTP_204_No_Content);
}

sub GET_image {
    my $self = shift;
    my $rest = shift;

    return $self->no_resource('account') unless $self->account;

    return $self->not_authorized()
        unless $self->account->user_can(
            user => $self->rest->user,
            permission => ST_READ_PERM,
        );

    my $image = $self->upload;
    return $self->no_resource('image') unless $image;

    $image->ensure_stored();
    return $self->serve_file(
        $rest, $image, $image->protected_uri, $image->content_length);
}

1;
