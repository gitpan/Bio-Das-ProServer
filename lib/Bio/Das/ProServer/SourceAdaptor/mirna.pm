#########
# Author: sgj (adapted from simpledb.pm)
# Maintainer: sgj
# Created: 2004-04-04
# Last Modified: 2004-04-04
# Builds miRNA DAS features from the miRNA database
#
package Bio::Das::ProServer::SourceAdaptor::mirna;

=head1 AUTHOR

sgj@sanger.ac.uk

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

sub length {
    0;
}

sub build_features {
  my ($self, $opts) = @_;
  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $dsn           = $self->{'dsn'};
  my $dbtable       = $dsn;
  my $organism      = $self->config->{'organism'};

  my $qsegment      = $self->transport->dbh->quote($segment);
  my $qbounds       = "";
  $qbounds          = qq(AND contig_start <= $end AND contig_end >= $start) if($start && $end);
  my $query         = qq(SELECT xsome,mirna_id,contig_start,contig_end,strand,description
			 FROM   mirna_chromosome_build,mirna
			 WHERE  mirna_id like "$organism%"
			 AND    mirna_chromosome_build.auto_mirna = mirna.auto_mirna
			 AND    xsome = $qsegment $qbounds);
  my $ref           = $self->transport->query($query);
  my @features      = ();

  for my $row (@{$ref}) {
    my ($start, $end) = ($row->{'contig_start'}, $row->{'contig_end'});
    ($start, $end) = ($end, $start) if($start > $end) ;

    push @features, {
                     'id'     => $row->{'mirna_id'},
                     'type'   => "miRNA",
                     'method' => "miRNA",
                     'start'  => $start,
                     'end'    => $end,
		     'ori'    => $row->{'strand'},
		     'note'   => $row->{'description'},
		     'link'   => "http://www.sanger.ac.uk/cgi-bin/Rfam/mirna/mirna_entry.pl?id=".$row->{'mirna_id'},
                    };
  }
  return @features;
}

1;
