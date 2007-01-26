#########
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2006-07-03
# Last Modified: $Date: 2007/01/26 23:10:42 $
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
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use IO::Socket;

our $VERSION = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

sub query {
  my $self  = shift;
  my $sockh = IO::Socket::INET->new(
				    PeerAddr => $self->config->{'host'},
				    PeerPort => $self->config->{'port'},
 				    Type     => SOCK_STREAM,
				    Proto    => 'tcp',
				   ) or die "Socket could not be opened: $!\n";
  $sockh->autoflush(1);

  print $sockh qq(--client "ProServer-pfetch$VERSION"), @_, "\n";

  local $/ = undef;

  my $result;
  $SIG{ALRM} = sub { die "timeout" };
  alarm(10);
  eval {
    $result = <$sockh>;
  };
  alarm(0);
  return $result || "";
}

1;
