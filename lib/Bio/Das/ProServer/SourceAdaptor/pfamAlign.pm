#########
# Author: rdf
# Maintainer: rdf
# Created: 2006-05-15
# Last Modified: 2006-05-15
# Builds DAS alignments from the pfam database
#
package Bio::Das::ProServer::SourceAdaptor::pfamAlign;

=head1 AUTHOR

Rob Finn <rdf@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
use Data::Dumper;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'alignment' => '1.0'
			    };
}


=head2 buildAlignment

 Title    : buildAlignment
 Function : This is method connects to the data source via the transport layer. Form here,
          : it builds the alignment data structure.  This is specific to the data source
          : as different alignments have very different requirements in terms of which blocks
          : of xml are required.
 Args     : Alignment request parameters. The alignment acc (query), the rows (optional), a subject +/- a range (optional),
          : and a subject coos system. Pfam alignments only understand "ProteinSequence".
 Returns  : alignment data object

=cut


sub buildAlignment {
    my ($self, $query, $rows, $subjectsRefs, $subCoos)   = @_;
    
    
    if($query =~ /PF\d+/){
	my $all_pos;
	my $qquery = $self->transport->dbh->quote($query);
     
	#Get the database version information;
	my $version = $self->transport->query("select pfam_release from VERSION");
	my $pfamAData = $self->transport->query(qq(SELECT  auto_pfamA, pfamA_id, pfamA_acc, num_full
						   FROM    pfamA
						   WHERE   pfamA_acc = $qquery)); 
	
        #Now get all of the alignment data
	my @statements;
	my $noSubjects;
	#Check that we can understand the subject coos system
	if($subCoos eq "" || $subCoos eq "ProteinSequence"){
	    #Build the sql to get the subjectsRefs
	    foreach my $subject (@$subjectsRefs){
		$noSubjects++;
		if($subject =~ /(\S+)\:(\d+)\,(\d+)/){
		    $subject = $1;
		    my $above = $2;
		    my $below = $3;
		    my $qsubject = $self->transport->dbh->quote($subject);
		    my $subjectPos = $self->transport->query(qq(SELECT tree_order 
								FROM   pfamA_reg_full, pfamseq
								WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
								AND    pfamA_reg_full.auto_pfamseq = pfamseq.auto_pfamseq
								AND    in_full=1
								AND    pfamseq_acc=$qsubject));
		    foreach my $posInfo (@$subjectPos){
			my $start = $posInfo->{'tree_order'} - $above;
			my $end = $posInfo->{'tree_order'} + $below;
			$all_pos .= "$start-$end,";
			print STDERR "$start, $end\n";
			push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
					     FROM   pfamA_reg_full, pfamseq
					     WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
					     AND    pfamA_reg_full.auto_pfamseq = pfamseq.auto_pfamseq
					     AND    in_full=1
					     AND    tree_order <= $end
					     AND    tree_order >= $start));
			
		    }
		}else{
		    my $qsubject = $self->transport->dbh->quote($subject);
		    push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
					 FROM   pfamA_reg_full, pfamseq
					 WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
					 AND    pfamA_reg_full.auto_pfamseq = pfamseq.auto_pfamseq
					 AND    in_full=1
					 AND    pfamseq_acc=$qsubject));
		    
		}
	    }
	    
	}
	if($rows){
	    my($start, $end) = split(/\-/, $rows);
	    $all_pos .= "$start-$end,";
	    push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
				 FROM   pfamA_reg_full, pfamseq
				 WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
				 AND    pfamA_reg_full.auto_pfamseq = pfamseq.auto_pfamseq
				 AND    in_full=1
				 AND    tree_order <= $end
				 AND    tree_order >= $start)) unless (!$start || !$end);
	}

	if(!$rows && ! $noSubjects){
	    #get the whole alignment
	    
	    push(@statements, qq(SELECT pfamseq_acc, pfamseq_id, md5, sequence, cigar, tree_order, seq_start, seq_end 
			     FROM   pfamA_reg_full, pfamseq
			     WHERE  auto_pfamA = $pfamAData->[0]->{'auto_pfamA'}
			     AND    pfamA_reg_full.auto_pfamseq = pfamseq.auto_pfamseq
			     AND    in_full=1));
	    
	    
	}
	
	
	#Now execute all of the queries;
	my @allres;
	foreach my $sql (@statements){
	    push(@allres, @{$self->transport->query($sql)});
	}
	#By now we should have all of the raw alinment data
	

	my @aliObjects;
	my %seen;
	my @segments;
	foreach my $row (@allres){
	    if(!$seen{$row->{'pfamseq_acc'}}){
		my @objectDetails;
		
		push(@aliObjects, {'version' => $row->{'md5'},
				   'intID' => $row->{'pfamseq_acc'},
				   'type' => "Protein sequence",
				   'dbSource' => "Pfam",
				   'dbVersion' => $version->[0]->{'pfam_release'},
				   'coos' => "UniProt",
				   'accession' =>  $pfamAData->[0]->{'pfamA_acc'},
				   'aliObjectDetail' => \@objectDetails,
				   'sequence' => $row->{'sequence'}});
		
		$seen{$row->{'pfamseq_acc'}}++;
	    }
	    
	    push(@segments, { 'cigar'    => $row->{'cigar'},
			      'objectId' => $row->{'pfamseq_acc'},
			      'start'    => $row->{'seq_start'},
			      'end'      => $row->{'seq_end'}, });
	}
	
	my @blocks;
	push(@blocks, {'blockOrder' => 1,
		      'segments' => \@segments
		      });
	
	my @ali;
	push(@ali,  {
	    'type' => "PfamFull",
	    'name' => $query,
	    'position' => "$rows",
	    'max' => $pfamAData->[0]->{'num_full'},
	    'alignObj' => \@aliObjects,
	    'blocks' => \@blocks,
	    'scores' => undef,
	    'geo3D' => undef, #Normally an array
	});
	
	return @ali;
    }
    
}
