#########
# Author: rmp
# Maintainer: rmp
# Created: 2004-02-16
# Last Modified: 2004-02-16
# Builds DAS features from Phenotypic Abnormalities Database
#
package Bio::Das::ProServer::SourceAdaptor::ensgenes;

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

sub length { 1; }

sub build_features {
  my ($self, $opts) = @_;
  my $slice         = $self->transport->chromosome_by_region($opts->{'segment'}, $opts->{'start'}, $opts->{'end'});
  my @features      = ();
  
  for my $g (@{$slice->get_all_Genes('ensembl')},
	     @{$slice->get_all_Genes('ensembl_havana_gene')},
	     @{$slice->get_all_Genes('havana')}){ #sr5 changed: 31/05/07 - includes havana and ensemble_havana_genes list (previously only ensembl).
    
    #print STDERR qq(g = $g (@{[$g->stable_id()]}) ***\n);
    
    my @links = @{$g->get_all_DBLinks()};
    my $label = $g->stable_id();
    
    #print STDERR join(", ", map { $_->dbname() } @links), "\n";
    
    for my $preferred (qw(RefSeq SWISSPROT SPTREMBL)) {
      for my $l (grep { $_->dbname() =~ /$preferred/xgi } @links) {
    	$label  = $l->display_id();
	last;
      }
    }
    

    push @features, {
		     'id'      => $g->stable_id(),
		     'label'   => $label,
		     'type'    => 'ensembl',
		     'method'  => 'ensembl',
		     'start'   => $g->start() + $slice->start() -1,
		     'end'     => $g->end()   + $slice->start() -1,
		     'strand'  => $g->strand(),
		     'note'    => $g->description(),
		    };
  }
  return @features;
}

1;
