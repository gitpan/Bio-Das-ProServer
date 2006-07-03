#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2004-02-03
# Last Modified: 2004-02-03
#
# PPID sourceadaptor broker
#
package Bio::Das::ProServer::SourceHydra::ppid;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use base "Bio::Das::ProServer::SourceHydra";

=head2 sources : Customised for the Genes2Cognition protein:protein interaction database

  Returns sources based on 'species' section in the config file

  my @sources = $ppidhydra->sources();

=cut
sub sources {
  my ($self)  = @_;
  my $species = $self->config->{'species'};
  my $dsn     = $self->{'dsn'};

  $species or return;

  return map {
    sprintf("%s_%s", $dsn, $_),
  } split(/,/, $species);
}

1;
