#########
# Author: ek3
# Maintainer: ek3
# Created: 2005-02-24
# Last Modified: 2005-02-24
# Builds simple DAS features from a EUF (Ensemble Upload Format) datasources
#
package Bio::Das::ProServer::SourceAdaptor::upload_euf;

=head1 AUTHOR

Eugene Kulesha <ek3@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features' => '1.0',
				'stylesheet' => '1.0',
			    };
}

sub das_stylesheet {
  my ($self, $opts) = @_;
  my $dsn           = $self->{'dsn'};
  (my $jid = $dsn) =~ s/hydraeuf_//;
  my $query = qq{ SELECT css FROM hydra_journal WHERE id = $jid };
  my $ref = $self->transport->query($query);
  return $ref->[0]->{'css'};
}

sub build_features {
  my ($self, $opts) = @_;
  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $dsn           = $self->{'dsn'};
  my $dbtable       = $dsn;

  #########
  # if this is a hydra-based source the table name contains the hydra name and needs to be switched out
  #
  my $hydraname     = $self->config->{'hydraname'};
  if($hydraname) {
    my $basename = $self->config->{'basename'};
    $dbtable =~ s/$hydraname/$basename/;
  }

  my $qsegment      = $self->transport->dbh->quote($segment);
  my $qbounds       = "";
  $qbounds          = qq(AND start <= '$end' AND end >= '$start') if($start && $end);
  my $query         = qq(SELECT segmentid,featureid,start,end,featuretype,strand,groupname,phase,score
			 FROM   $dbtable
			 WHERE  segmentid = $qsegment $qbounds);
  my $ref           = $self->transport->query($query);
  my @features      = ();

#  warn("SQL: $query");

  for my $row (@{$ref}) {
    my ($start, $end, $strand) = ($row->{'start'}, $row->{'end'}, $row->{'strand'});

    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    push @features, {
                     'id'     => $row->{'featureid'},
                     'type'   => $row->{'featuretype'} || $dbtable,
                     'method' => $row->{'featuretype'} || $dbtable,
                     'start'  => $start,
                     'end'    => $end,
		     'ori' => $strand,
		     'score' => $row->{'score'},
		     'phase' => $row->{'phase'},
		     'group' => $row->{'groupname'}
                    };
  }
  return @features;
}

1;
