package Socialtext::Rest::WorkspaceUsers;
# @COPYRIGHT@

use warnings;
use strict;

use base 'Socialtext::Rest::Users';
use Socialtext::JSON;
use Socialtext::HTTP ':codes';
use Socialtext::WorkspaceInvitation;
use Socialtext::User::Find::Workspace;
use Class::Field qw/field/;

sub allowed_methods {'GET, HEAD, POST'}
sub collection_name { "Users in workspace " . $_[0]->ws }

field '_workspace',
    '-init' => 'Socialtext::Workspace->new(name => $self->ws)';

sub create_user_find {
    my $self = shift;
    my $limit = $self->rest->query->param('count') ||
                $self->rest->query->param('limit') ||
                25;
    my $offset = $self->rest->query->param('offset') || 0;

    my $filter = $self->rest->query->param('filter');
    my $workspace = $self->_workspace;
    die "invalid workspace" unless $workspace;

    return Socialtext::User::Find::Workspace->new(
        viewer => $self->rest->user,
        limit => $limit,
        offset => $offset,
        filter => $filter,
        workspace => $workspace,
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
                || $checker->check_permission('email_out');
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
        
            $workspace->add_user( user => $user,
                                  role => $role );
            $workspace->assign_role_to_user( user => $user, role => $role );
        }
    };
    
    if ( my $e = Exception::Class->caught('Socialtext::Exception::DataValidation') ) {
        $rest->header(
                      -status => HTTP_400_Bad_Request,
                      -type   => 'text/plain' );
        return join( "\n", $e->messages );
    } elsif ( $@ ) {
        $rest->header(
            -status => HTTP_400_Bad_Request,
            -type   => 'text/plain' );
        # REVIEW: what kind of system logging should we be doing here?
        return "$@";
    }


    $rest->header(
        -status => HTTP_201_Created,
        -type   => 'application/json',
        -Location => $self->full_url('/', ''),
    );

    return '';
}

1;
