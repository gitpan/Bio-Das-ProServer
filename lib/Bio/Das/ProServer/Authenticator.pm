#########
# Author:        Andy Jenkinson
# Created:       2008-02-20
# Last Modified: $Date: 2008-12-03 23:35:54 +0000 (Wed, 03 Dec 2008) $ $Author: zerojinx $
# Id:            $Id: Authenticator.pm 549 2008-12-03 23:35:54Z zerojinx $
# Source:        $Source$
# $HeadURL: https://proserver.svn.sourceforge.net/svnroot/proserver/tags/spec-1.53/lib/Bio/Das/ProServer/Authenticator.pm $
#
# Stub Authenticator for controlling access.
#
package Bio::Das::ProServer::Authenticator;

use strict;
use warnings;
use Carp;
use HTTP::Response;

our $VERSION = do { my ($v) = (q$LastChangedRevision: 549 $ =~ /\d+/mxg); $v; };

sub new {
  my ($class, $self) = @_;
  $self ||= {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {return;}

sub authenticate {
  my ($self, $params) = @_;
  # Deny by default
  return $self->deny($params);
}

sub deny {
  my ($self, $params) = @_;
  $self->{'debug'} && carp 'Authenticator denied request';
  my $response = HTTP::Response->new('403');
  $response->content_type('text/plain');
  $response->content(sprintf q(Forbidden: authentication failed for '%s' command on '%s'),
                             $params->{'call'}||'unknown',
                             $self->{'dsn'}||'unknown');
  return $response;
}

sub allow {
  my $self = shift;
  $self->{'debug'} && carp 'Authenticator allowed request';
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::Authenticator - authenticates DAS requests

=head1 VERSION

$LastChangedRevision: 549 $

=head1 SYNOPSIS

  my $auth = Bio::Das::ProServer::Authenticator::<impl>->new({
    'dsn'    => $, # source name
    'config' => $, # source config
    'debug'  => $, # debug flag
  });
  
  my $allow = $auth->authenticate({
    'socket'    => $, # handle
    'peer_addr' => $, # packed
    'peer_port' => $, # number
    'request'   => $, # HTTP::Request object
    'cgi'       => $, # CGI object
    'call'      => $, # DAS command
  });

=head1 DESCRIPTION

This is a stub class intended to be extended.

=head1 CONFIGURATION AND ENVIRONMENT

See subclasses.

=head1 DIAGNOSTICS

  my $auth = Bio::Das::ProServer::Authenticator::<impl>->new({
    ...
    'debug'  => 1,
  });

=head1 SUBROUTINES/METHODS

=head2 new : Instantiates a new object.

  my $auth = Bio::Das::ProServer::Authenticator::<impl>->new({
    'dsn'    => $, # source name
    'config' => $, # source config
    'debug'  => $, # debug flag
  });

=head2 authenticate : Applies authentication to a request.

  my $allow = $oAuth->authenticate({
    'socket'    => $, # handle
    'peer_addr' => $, # packed
    'peer_port' => $, # number
    'request'   => $, # HTTP::Request object
    'cgi'       => $, # CGI object
    'call'      => $, # DAS command
  });
  
Authenticates a request by making use of various request data. If requests are
to be denied, the authentication operation should return an appropriate
HTTP::Response object. Otherwise nothing (undef) is returned.

This stub method denies all requests with a standard 403 (Forbidden) response.

=head2 deny : Convenience method useful for indicating authentication failure

  sub authenticate {
    my ($self, $params) = @_;
    # Perform authentication
    return $self->deny($params);
  }
  
  Returns a standard 403 (Forbidden) response.

=head2 allow : Convenience method useful for indicating authentication success

  sub authenticate {
    my ($self, $params) = @_;
    # Perform authentication
    return $self->allow($params);
  }
  
  Simply returns an undefined value.

=head2 init : Executed upon construction

This stub method does nothing.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

None reported.

=head1 DEPENDENCIES

=over

=item L<Carp>

=item L<HTTP::Response>

=back

=head1 AUTHOR

Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 EMBL-EBI

=cut
