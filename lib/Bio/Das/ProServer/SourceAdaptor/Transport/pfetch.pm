#########
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2006-07-03
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Pfetch socket-based transport layer
#
package Bio::Das::ProServer::SourceAdaptor::Transport::pfetch;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use IO::Socket;

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 query : Run a query against pfetch

  my $sPfetchResponseData = $pfetchTransport->query(....);

  Pfetch service is configured using the 'host' and 'port' parameters
  in proserver.ini for adaptors using this transport

=cut

sub query {
  my $self  = shift;
  my $sockh = IO::Socket::INET->new(
				    PeerAddr => $self->config->{'host'},
				    PeerPort => $self->config->{'port'},
 				    Type     => SOCK_STREAM,
				    Proto    => 'tcp',
				   ) or die "Socket could not be opened: $!\n";
  $sockh->autoflush(1);

  local $" = ' ';
  my $str  = qq(--client "ProServer-pfetch$VERSION" @_\n);
  print $sockh $str;

  local $/ = undef;

  my $result;
  $SIG{ALRM} = sub { die 'timeout' };
  alarm(10);
  eval {
    $result = <$sockh>;
  };
  alarm(0);
  return $result || '';
}

1;
