#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2007-01-30
# Last Modified: $Date: 2007/11/20 20:12:21 $ $Author: rmp $
#
# Transport layer for DBI/mole
#
package Bio::Das::ProServer::SourceAdaptor::Transport::mole;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::dbi);

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 init : Load & process mole.ini

  $oMoleTransport->init();

=cut
sub init {
  my $self = shift;
  my $dbh  = $self->dbh();

  for my $db (qw(mushroom uniprot)) {
    my $ref = $self->dbh->selectall_arrayref(q(SELECT database_name FROM ini WHERE database_category=? AND current='yes'), {}, $db);
    $self->config->{$db} = $ref->[0]->[0];
  }
  return;
}

1;
