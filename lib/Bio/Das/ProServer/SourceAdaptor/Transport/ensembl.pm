#########
# Author: rmp
# Maintainer: rmp
# Created: 2004-04-23
# Last Modified: 2004-04-23
# Transport layer for Ensembl API
#
package Bio::Das::ProServer::SourceAdaptor::Transport::ensembl;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

BEGIN {
  my ($eroot) = $ENV{'ENS_ROOT'}     =~ m|([a-zA-Z0-9_/\.\-]+)|;
  my ($broot) = $ENV{'BIOPERL_HOME'} =~ m|([a-zA-Z0-9_/\.\-]+)|;

  unshift(@INC,"$eroot/ensembl/modules");
  unshift(@INC,"$broot");
}

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::Das::ProServer::SourceAdaptor::Transport::generic;
use vars qw(@ISA);
@ISA = qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);


sub adaptor {
  my $self = shift;
  unless($self->{'_adaptor'}) {
    my $host     = $self->config->{'host'}     || "localhost";
    my $port     = $self->config->{'port'}     || "3306";
    my $dbname   = $self->config->{'dbname'};
    my $username = $self->config->{'username'} || "ensro";
    my $password = $self->config->{'password'} || "";

    $self->{'_adaptor'} ||= Bio::EnsEMBL::DBSQL::DBAdaptor->new(
								-host   => $host,
								-port   => $port,
								-user   => $username,
								-dbname => $dbname,
							       );
  }

  return $self->{'_adaptor'};
}

sub chromosome_by_region {
  my ($self, $chr, $start, $end) = @_;
  my $slice = $self->adaptor->get_SliceAdaptor->fetch_by_region('chromosome', $chr, $start, $end);
  return $slice;
}

1;
