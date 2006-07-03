#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2005-08-03
# Last Modified: 2005-08-03
#
# OMIM features (based on simpledb.pm)
#
package Bio::Das::ProServer::SourceAdaptor::ens_ncbi_35_morbid;

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
  return if(length($segment) > 2);
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $qsegment      = $self->transport->dbh->quote($segment);
  my $qbounds       = "";
#  $qbounds          = qq(AND cg.seq_region_start <= '$end' AND cg.seq_region_end >= '$start') if($start && $end);
#  my $query         = qq(SELECT DISTINCT g.gene_symbol, g.omim_id, d.disease, sr.name,
#			                 cg.seq_region_start      AS start,
#			                 cg.seq_region_end        AS end
#			 FROM homo_sapiens_disease_32_35e.disease AS d,
#			      homo_sapiens_disease_32_35e.gene    AS g,
#			      xref                                AS cx,
#			      object_xref                         AS cox,
#			      translation                         AS tr,
#			      transcript                          AS t,
#			      gene                                AS cg,
#			      seq_region                          AS sr
#			 WHERE d.id              = g.id
#			 AND   cx.display_label  = g.omim_id
#			 AND   cx.external_db_id = 1500
#			 AND   cox.xref_id       = cx.xref_id
#			 AND   cox.ensembl_id    = tr.translation_id
#			 AND   tr.transcript_id  = t.transcript_id
#			 AND   cg.gene_id        = t.gene_id
#			 AND   cg.seq_region_id  = sr.seq_region_id
#			 AND   sr.name           = $qsegment $qbounds);

  $qbounds          = qq(AND chr_start <= '$end' AND chr_end >= '$start') if($start && $end);
  my $query         = qq(SELECT gene_symbol, omim_id, disease, chr, chr_start AS start, chr_end AS end
			 FROM   ens_ncbi_35_morbid
			 WHERE  chr = $qsegment $qbounds);

#  $query =~ s/\s+/ /smg;
#  print STDERR $query, "\n";

  my $ref           = $self->transport->query($query);
  my @features      = ();
  my $i             = 1;
  for my $row (@{$ref}) {
    my ($start, $end) = ($row->{'start'}, $row->{'end'});
    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    push @features, {
                     'id'           => "phenotype:$row->{'omim_id'}/$i",
		     'label'        => $row->{'omim_id'},
                     'type'         => "$row->{'gene_symbol'}:$row->{'disease'}",
		     'typecategory' => "miscellaneous",
                     'method'       => $row->{'gene_symbol'},
                     'start'        => $start,
                     'end'          => $end,
		     'link'         => "http://www.ncbi.nlm.nih.gov/entrez/dispomim.cgi?id=$row->{'omim_id'}",
		     'linktxt'      => $row->{'omim_id'},
		     'group'        => "phenotype:$row->{'omim_id'}",
		     'grouptype'    => "phenotype",
		     'ori'          => '',
		     'score'        => "0",
		     'phase'        => "0",
                    };
    $i++;
  }
  return @features;
}

1;
