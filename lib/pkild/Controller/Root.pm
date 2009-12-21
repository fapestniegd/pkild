package pkild::Controller::Root;

use strict;
use warnings;
use base 'Catalyst::Controller';
use YAML;
use JSON;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

pkild::Controller::Root - Root Controller for pkild

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 default

=cut

sub default : Private {
    my ( $self, $c ) = @_;
    # remove this if not running in apache (can we do this automatically?)
    $c->require_ssl;
    ############################################################################
    # Attempt to authenticate
    ############################################################################
    if( (defined($c->req->param("login")))&&(defined($c->req->param("password")))){
        $c->authenticate({
                           id       => $c->req->param("username"), 
                           password => $c->req->param("password") 
                         });
        if(defined($c->user)){
            $c->session->{'user'}=$c->user;
        }else{
            $c->stash->{'ERROR'}="Authentication Failed."; 
        }
    }

    ############################################################################
    # Log us out if ?logout=1 was sent
    ############################################################################
    if(defined($c->req->param("logout"))){ 

        # remove all user handles
        delete $c->session->{'user'};
        delete $c->session->{'username'};

        # expire our session
        $c->delete_session("logout");

        # send us home, so subsequent page refreshes won't post logout
        $c->res->redirect($c->request->headers->referer);
        $c->detach();
    }

    if( $c->request->arguments->[0]){
    ############################################################################
    # 
    ############################################################################
        if( $c->request->arguments->[0] eq "jstree" ){
            $c->res->body(to_json($c->model('Certificates')->tree(), {'pretty' => 1}));
        }
        if( $c->request->arguments->[0] eq "action" ){
            # send the new actionbox
            if( $c->request->arguments->[1]){
                
                if( $c->request->arguments->[2] eq "selected" ){

                    if( $c->request->arguments->[3] eq "NEW_ROOT_CA" ){
                        $c->session->{'menunames'}=[ 'Domain', 'Help' ];
                        $c->session->{'menudata'}->{'Help'}->{'comments'} = "Create a new root Certificate Authority.";
                    }
                    $c->res->body( $c->view('TT')->render(
                                                           $c,
                                                           'actionbox.tt',
                                                           { 
                                                             additional_template_paths => [ $c->config->{root} . '/src'],
                                                             'menunames'               => $c->session->{'menunames'},
                                                             'menudata'                => $c->session->{'menudata'},
                                                             'default_tab'             => $c->session->{'default_tab'}
                                                           }
                                                         )
                                 );
                }elsif($c->request->arguments->[2] eq "open" ){
                    # add the tab node_id to the default open tabs
                    push (@{ $c->session->{'opened_tabs'} },$c->request->arguments->[3]);
                    $c->res->body( $c->view('TT')->render(
                                                           $c,
                                                           'open_tabs.tt',
                                                           { 
                                                             additional_template_paths => [ $c->config->{root} . '/src'],
                                                             'open_tabs'               => $c->session->{'open_tabs'},
                                                           }
                                                         )
                                 );
                }elsif($c->request->arguments->[2] eq "close" ){
                    # remove the tab node_id from the default open tabs
                    while (my $item = shift @{ $c->session->{'opened_tabs'} }){
                        push(@{ $c->session->{'opened_tabs'} },$item) unless ($item eq $c->request->arguments->[3]);
                    }
                    $c->res->body("[ \"". join("\",\"",$c->session->{'opened_tabs'}). "\" ]");
                }
            }
        }
    }

    ############################################################################
    # Update the default tab in the session if changed
    ############################################################################
    if(defined($c->req->param("change_tab"))){ 
        $c->session->{'default_tab'} = $c->req->param("change_tab"); 
        $c->res->body("Default tab changed to ".$c->session->{'default_tab'}.".");
    }
   
    my $form_data=$c->config->{'layout'};
    if(! defined $c->session->{menudata}){
        $c->session->{menudata}=$form_data->{'forms'};
    }
    # Remember what we set things to.
    foreach my $value ($c->req->param()){
        for(my $idx=0; $idx < $#{ $c->session->{menudata}->{ $c->session->{'default_tab'} }->{'fields'} }; $idx++){
            if($value eq  $c->session->{menudata}->{ $c->session->{'default_tab'} }->{'fields'}->[$idx]->{'name'}){
                $c->session->{menudata}->{ $c->session->{'default_tab'}}->{'fields'}->[$idx]->{'value'} = $c->req->param($value);
            }
        }
    }
    ############################################################################
    # If we're logged in, send us to the application, othewise the login page.
    ############################################################################
    if(!defined $c->session->{'user'}){
        $c->stash->{template}="login.tt";
    }else{
        if($c->check_user_roles( "certificate_administrators" )){
            $c->session->{menunames}=$form_data->{'order'}->{'administrator'};
        }else{
            my $form_data = $c->config->{'layout'};
            $c->session->{menunames}=$form_data->{'order'}->{'user'};
        }
        $c->session->{'default_tab'}=$c->stash->{menunames}->[0] unless defined $c->session->{'default_tab'};
        $c->stash->{'default_tab'} = $c->session->{'default_tab'};
        $c->stash->{menunames}=$c->session->{'menunames'};
        $c->stash->{menudata}=$c->session->{'menudata'};
        $c->stash->{template}="application.tt";
    }
}

sub login : Global {
    my ( $self, $c ) = @_;
    $c->authenticate({
                       id          => $c->req->param("login"), 
                       password    => $c->req->param("password") 
                      });
    $c->res->body("Welcome " . $c->user->username . "!");
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

James S. White,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
