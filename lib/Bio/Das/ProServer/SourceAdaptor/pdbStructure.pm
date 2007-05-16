#########
# Author:        rdf
# Maintainer:    rdf
# Created:       2006-04-01
# Last Modified: $Date: 2007/02/20 18:02:03 $ $Author: rmp $
# Id:            $Id: pdbStructure.pm,v 2.52 2007/02/20 18:02:03 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor/pdbStructure.pm,v $ 
# $HeadURL$
#
# Builds DAS structures from the WTSI instance of PDB database
#
package Bio::Das::ProServer::SourceAdaptor::pdbStructure;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);
use Bio::Pfam::Structure::Chainset;

our $VERSION  = do { my @r = (q$Revision: 2.52 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'structure' => '1.0'
			    };
  return;
}

sub build_structure {
  my ($self, $query, $chains_ref, $model_no) = @_;

  if(!-e "/home/rob/Work/Development/DasStructure/pdbs/$query.pdb") {
    return {};
  }

  open my $fh, q(<), "/home/rob/Work/Development/DasStructure/pdbs/$query.pdb" or warn "Could not open pdb file, $query:[$!]\n";
  my $pdb = Bio::Pfam::Structure::Chainset->new;
  $pdb->read_pdb($fh);
  my (@objects, @chains, @connects);
	
  push @objects, {
		  'version'       => '1-APR-2007',
		  'type'          => 'protein',
		  'dbSource'      => 'WTSI-SRS-PDB',
		  'dbVersion'     => 'UNKNOWN',
		  'dbCoordSys'    => 'PDB',
		  'dbAccessionId' => $query,
		  'ObjectDetails' => [],
		 };

  for my $chain ($pdb->each) {
    my @residues;
    push @chains, {
		   'id'          => $chain->chain_id,
		   'modelNumber' => q(),
		   'SwissprotId' => q(),
		   'groups'      => \@residues,
		  };

    for my $res ($chain->each) {
      my @atoms;
      push @residues, {
		       'name'  => $res->type,
		       'type'  => 'amino',
		       'id'    => $res->residue_no,
		       'icode' => q(),
		       'atoms' => \@atoms,
		      };

      for my $atom ($res->each) {
	my @xyz = $atom->xyz;
	push @atoms, {
		      'atomId'     => $atom->number,
		      'atomName'   => $atom->type,
		      'x'          => $xyz[0],
		      'y'          => $xyz[1],
		      'z'          => $xyz[2],
		      'occupancy'  => q(1.00),
		      'tempFactor' => $atom->temperature,
		      'altLoc'     => q(),
		     };
      }
    }
  }

  return {
	  'objects'  => \@objects,
	  'chains'   => \@chains,
	  'connects' => \@connects,
	 };
}

1;

__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::pdbStructure - Builds DAS structures from the WTSI instance of PDB database

=head1 VERSION

$Revision $

=head1 AUTHOR

Rob Finn <rdf@sanger.ac.uk>.

=head1 DESCRIPTION

This is an example PDB Structure source. To use in your own code, use
your favourite PDB parser or contact me for mine.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
