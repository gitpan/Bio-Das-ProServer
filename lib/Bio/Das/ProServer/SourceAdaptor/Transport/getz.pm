#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-06-13
# Last Modified: $Date: 2007/11/20 20:12:21 $ $Author: rmp $
#
# Pulls features over command-line SRS/getz transport
#
package Bio::Das::ProServer::SourceAdaptor::Transport::getz;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 query : Run a query against getz

  my $sGetzData = $getzTransport->query('-e', '[....]');

=cut
sub query {
  my $self     = shift;
  my ($sgetz)  = ($self->config->{'getz'} || '/usr/local/bin/getz') =~ /([a-zA-Z0-9\-\_\.\/]+)/;
  my $query    = join(' ', @_);
  my ($squery) = $query =~ /([a-zA-Z0-9\[\]\(\)\{\}\.\-_\>\<\:\'\" \|]+)/;
  warn qq(Detainted '$squery' != '$query') if($squery ne $query);
  return `$sgetz $squery`;
}

1;
