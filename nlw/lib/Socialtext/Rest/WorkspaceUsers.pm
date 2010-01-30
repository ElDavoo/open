package Socialtext::Rest::WorkspaceUsers;
# @COPYRIGHT@
use Moose;
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::WorkspaceInvitation;
use Socialtext::User::Find::Workspace;
use namespace::clean -except => 'meta';

extends 'Socialtext::Rest::Users';

sub allowed_methods {'GET, HEAD, POST'}
sub collection_name { "Users in workspace " . $_[0]->ws }

has '_workspace' => (
    is => 'ro', isa => 'Socialtext::Workspace',
    lazy_build => 1,
);
sub _build__workspace {
    my $self = shift;
    Socialtext::Workspace->new(name => $self->ws);
};

sub _build_user_find {
    my $self = shift;
    my $filter = $self->rest->query->param('filter');
    my $workspace = $self->_workspace;
    die "invalid workspace" unless $workspace;

    return Socialtext::User::Find::Workspace->new(
        viewer => $self->rest->user,
        limit  => $self->items_per_page,
        offset => $self->start_index,
        filter => $filter,
        workspace => $workspace,
        direct => $self->rest->query->param('direct') || 0,
        minimal => $self->rest->query->param('minimal') || 0,
        order => $self->rest->query->param('order') || '',
        reverse => $self->rest->query->param('reverse') || 0,
        all => $self->rest->query->param('all') || 0,
    )
}

sub if_authorized {
    my $self = shift;
    my $method = shift;
    my $call = shift;

    my $acting_user = $self->rest->user;
    my $checker = $self->hub->checker;

    if ($method eq 'POST') {
        return $self->not_authorized 
            unless $acting_user->is_business_admin()
                || $acting_user->is_technical_admin()
                || $checker->check_permission('admin_workspace');
    }
    elsif ($method eq 'GET') {
        return $self->not_authorized
            unless $checker->check_permission('admin_workspace')
                || $checker->check_permission('email_out')
                || $acting_user->is_business_admin();
    }
    else {
        return $self->bad_method;
    }

    return $self->$call(@_);
}

sub POST {
    my $self = shift;
    return $self->if_authorized('POST', '_POST', @_);
}

sub _POST {
    my $self = shift;
    my $rest = shift;

    my $workspace = $self->_workspace
        || return $self->no_workspace();

    my $create_request_hash = decode_json( $rest->getContent() );

    unless ( $create_request_hash->{username} and
             $create_request_hash->{rolename} ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type  => 'text/plain', );
        return "username, rolename required";
    }

    my $workspace_name = $self->ws;
    my $username = $create_request_hash->{username};
    my $rolename = $create_request_hash->{rolename};

    eval {
        if ( $create_request_hash->{send_confirmation_invitation} ) {
            my $from_user = $self->rest->user;
            my $username = $create_request_hash->{username};
            die "username is required\n" unless $username;
            if ( $create_request_hash->{from_address} ) {
                my $from_address = $create_request_hash->{from_address};
                $from_user =
                  Socialtext::User->new( email_address => $create_request_hash->{from_address} );
                die "from_address: $from_address must be valid Socialatext user\n"
                  unless $from_user;
            }
            my $invitation =
              Socialtext::WorkspaceInvitation->new( workspace => $workspace,
                                                    from_user => $from_user,
                                                    invitee   => $username );
            $invitation->send( );
        } else {
            my $user = Socialtext::User->new( username => $username );
            my $role = Socialtext::Role->new( name => $rolename );
        
            unless( $user && $role ) {
                die "both username, rolename must be valid\n";
            }
        
            $workspace->assign_role_to_user( user => $user, role => $role );
        }
    };
    
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        warn $e;
        $rest->header(-status => HTTP_400_Bad_Request, -type => 'text/plain');
        return join( "\n", $e->messages );
    } elsif ( $@ ) {
        warn $@;
        $rest->header(-status => HTTP_400_Bad_Request, -type => 'text/plain');
        return "$@";
    }


    $rest->header(
        -status => HTTP_201_Created,
        -type   => 'application/json',
        -Location => $self->full_url('/', ''),
    );

    return '';
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
