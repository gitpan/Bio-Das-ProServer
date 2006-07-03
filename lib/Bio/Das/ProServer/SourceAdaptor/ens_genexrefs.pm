#########
# Author: jws
# Maintainer: jws
# Created: 2004-02-16
# Last Modified: 2004-02-16
# Builds DAS features from the xrefs of a gene.
#
package Bio::Das::ProServer::SourceAdaptor::ens_genexrefs;

=head1 AUTHOR

Jim Stalker <jws@sanger.ac.uk>.

Copyright (c) 2005 The Sanger Institute

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
    my $adaptor = $self->transport->adaptor->get_GeneAdaptor;
    my $id = $opts->{'segment'};
    my @features;

    # ID can be an Ensembl gene/transcript/peptide id, or an xref id.  Need to
    # return features of the other type.
    # First, try Ensembl features in order gene:transcript:pep.
    my $gene = $adaptor->fetch_by_stable_id($id);
    $gene ||= $adaptor->fetch_by_transcript_stable_id($id);
    $gene ||= $adaptor->fetch_by_Peptide_id;

    if ($gene){
	for my $l (@{$gene->get_all_DBLinks()}) {
	    push @features, {
		     'id'      => $l->primary_id,
		     'label'   => $l->display_id,
		     'type'    => $l->database,
		     'method'  => 'xref',
		     'start'   => 0,
		     'end'     => 0,
		     'note'    => $l->status,
		     };
	}
    }
    else {
	# No gene.  See if we've been given an Xref id instead.
	# NB - an Xref might map to multiple genes (particularly as we don't
	# know the database it's an Xref to).
	for my $g (@{$adaptor->fetch_all_by_external_name($id)}){;
	    my $xref = $g->display_xref;
	    my $label = $xref ? $xref->display_id : $g->stable_id;
	    push @features, {
		     'id'      => $g->stable_id,
		     'label'   => $label,
		     'type'    => 'ensembl',
		     'method'  => 'xref',
		     'start'   => 0,
		     'end'     => 0,
		     'note'    => $g->description,
		     };
	}		
    }

  return @features;
}

1;
