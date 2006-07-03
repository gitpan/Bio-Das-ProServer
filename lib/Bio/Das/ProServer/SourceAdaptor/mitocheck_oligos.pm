#########
# Author: rmp for jkh1
# Maintainer: rmp
# Created: 2004-11-11
# Last Modified: 2004-11-11
# Builds mitocheck oligo features from the mitocheck db
#
package Bio::Das::ProServer::SourceAdaptor::mitocheck_oligos;

=head1 AUTHOR

rmp@sanger.ac.uk

Copyright (c) 2004 The Sanger Institute

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
  my $qsegment      = $self->transport->dbh->quote($segment);
  my $qbounds       = "";
  $qbounds          = qq(AND (start1 <= $end OR start2 <= $end)
			 AND (end1 >= $start OR end2 >= $start)) if($start && $end);
  my $query         = qq(SELECT oligo_pairID,transcriptID,chromosome,start1,end1,start2,end2
			 FROM   dsRNA_map_info
			 WHERE  chromosome=$qsegment $qbounds
			 GROUP BY oligo_pairID);
  my $ref           = $self->transport->query($query);
  my @features      = ();

  for my $row (@{$ref}) {
    my ($start1, $end1) = ($row->{'start1'}, $row->{'end1'});
    my ($start2, $end2) = ($row->{'start2'}, $row->{'end2'});


    push @features, {
                     'id'     => $row->{'oligo_pairID'},
                     'type'   => "mitocheck_oligo",
                     'method' => "mitocheck",
                     'start'  => $start1,
                     'end'    => $end1,
		     'ori'    => "+",
		     'group'  => $row->{'oligo_pairID'},
                    };

    if($start2 && $end2) {
      push @features, {
		       'id'     => $row->{'oligo_pairID'},
		       'type'   => "mitocheck_oligo",
		       'method' => "mitocheck",
		       'start'  => $start2,
		       'end'    => $end2,
		       'ori'    => "+",
		       'group'  => $row->{'oligo_pairID'},
                    };
    }
  }
  return @features;
}

1;
