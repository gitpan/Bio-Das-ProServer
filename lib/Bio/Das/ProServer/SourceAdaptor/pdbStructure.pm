#########
# Author:        rdf
# Maintainer:    rdf
# Created:       2006-04-01
# Last Modified: 2006-06-22
# Builds DAS structures from the WTSI instance of PDB database
#
package Bio::Das::ProServer::SourceAdaptor::pdbStructure;

=head1 AUTHOR

Rob Finn <rdf@sanger.ac.uk>.

This is an example PDB Structure source. To use in your own code, use
your favourite PDB parser or contact me for mine.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
use Bio::Pfam::Structure::Chainset;

use Data::Dumper;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'structure' => '1.0'
			    };
}

sub buildStructure {
    my $self = shift;
    my $query = shift;
    my $chainsRef = shift;
    my $modelNo = shift;
    
    
    if(-e "/home/rob/Work/Development/DasStructure/pdbs/$query.pdb"){
	open (PDB, "/home/rob/Work/Development/DasStructure/pdbs/$query.pdb") || warn "Could not open pdb file, $query:[$!]\n";
	my $pdb = Bio::Pfam::Structure::Chainset->new;
	$pdb->read_pdb(\*PDB);
	my (@objects, @chains, @connects);
	
	push(@objects, {'version' => "1-APR-2007",
			'type' => "protein",
			'dbSource' => "WTSI-SRS-PDB",
			'dbVersion' => "UNKNOWN",
			'dbCoordSys' => "PDB",
			'dbAccessionId' => $query,
			'ObjectDetails' => []});
	
	
	foreach my $chain ($pdb->each){
	    my @residues;
	    push(@chains, {'id' => $chain->chain_id,
			   'modelNumber' => "",
			   'SwissprotId' => "",
			   'groups' => \@residues});
	    foreach my $res ($chain->each){
		my @atoms;
		push(@residues, {'name'  => $res->type,
				 'type'  => "amino",
				 'id'    => $res->residue_no,
				 'icode' => "",
				 'atoms' => \@atoms}); 
		foreach my $atom ($res->each){
		    my @xyz = $atom->xyz;
		    push(@atoms, {'atomId'     => $atom->number,
				  'atomName'   => $atom->type,
				  'x'          => $xyz[0],
				  'y'          => $xyz[1],
				  'z'          => $xyz[2],
				  'occupancy'  => "1.00",
				  'tempFactor' => $atom->temperature,
				  'altLoc'     => ""});
		}
		
	    }
	}
    
	my %dasStructure = ( "objects"  => \@objects,
			     "chains"   => \@chains,
			     "connects" => \@connects );
    
	return \%dasStructure;
    }
}
