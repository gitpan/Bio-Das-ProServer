#########
# Author: dkj
# Maintainer: dkj
# Created: 2005-11-15
# Last Modified: 2005-11-21
#
# hydra broker for simplescore_db databases
#
package Bio::Das::ProServer::SourceHydra::simplescoreh_db;

=head1 AUTHOR

David Jackson <dj3@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use Bio::Das::ProServer::SourceHydra;
use vars qw(@ISA);
@ISA = qw(Bio::Das::ProServer::SourceHydra);

sub sources {
  my $self = shift;
  my $dsn      = $self->{'dsn'};
  return map {$dsn.$_} map {values %{$_}} @{$self->transport->query(qq(SELECT DISTINCT experiment_id FROM data))};
}

1;
