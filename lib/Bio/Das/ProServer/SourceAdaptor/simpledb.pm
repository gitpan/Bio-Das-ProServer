#########
# Author: rmp
# Maintainer: rmp
# Created: 2003-12-12
# Last Modified: 2003-12-12
# Builds simple DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::simpledb;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

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
			    };
}

sub build_features {
  my ($self, $opts) = @_;
  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $dsn           = $self->{'dsn'};
  my $dbtable       = $self->config->{'dbtable'} || $dsn;

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
  my $query         = qq(SELECT segmentid,featureid,start,end,type,note,link
			 FROM   $dbtable
			 WHERE  segmentid = $qsegment $qbounds);
  my $ref           = $self->transport->query($query);
  my @features      = ();

  for my $row (@{$ref}) {
    my ($start, $end) = ($row->{'start'}, $row->{'end'});
    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    push @features, {
                     'id'     => $row->{'featureid'},
                     'type'   => $row->{'type'} || $dbtable,
                     'method' => $row->{'type'} || $dbtable,
                     'start'  => $start,
                     'end'    => $end,
		     'note'   => $row->{'note'},
		     'link'   => $row->{'link'},
                    };
  }
  return @features;
}

1;
