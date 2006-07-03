#########
# Author: rdf
# Maintainer: rdf
# Created: 2006-01-25
# Last Modified: 2006-05-15
# Builds simple DAS features from the pfam database
#
package Bio::Das::ProServer::SourceAdaptor::pfam;

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
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
    my $self                = shift;
    
    $self->{'capabilities'} = {
	'features' => '1.0',
	'sequence' => '1.0',
	};
}

sub _load_segment_info {
  my ($self, $segment) = @_;
  my $qsegment         = $self->transport->dbh->quote($segment);
  my $ref              = $self->transport->query(qq(SELECT md5,length
                                                    FROM   pfamseq
                                                    WHERE  pfamseq_acc = $qsegment));

  return $ref->[0];
}

sub segment_version {
  my ($self, $segment) = @_;
  return $self->_load_segment_info($segment)->{'md5'};
}

sub length {
  my ($self, $segment) = @_;
  return $self->_load_segment_info($segment)->{'length'};
}

sub build_features {
    my ($self, $opts) = @_;
    my $segment       = $opts->{'segment'};
    my $start         = $opts->{'start'};
    my $end           = $opts->{'end'};
    my $dsn           = $self->{'dsn'};
    
    
    
    my $qsegment      = $self->transport->dbh->quote($segment);
  

    #Okay - what features do we want to serve from Pfam?
    # Pfam-A
    # Pfam-B
    
    #Lets first deal with Pfam-As
    my $qbounds       = "";
    $qbounds          = qq(AND seq_start <= '$end' AND seq_end >= '$start') if($start && $end);
    
    # Select the pfamA regions
    my $query         = qq(SELECT pfamA_id, pfamA_acc, pfamA.description, md5, seq_start, seq_end, domain_evalue_score 
			   FROM   pfamA, pfamA_reg_full, pfamseq 
			   WHERE  pfamA.auto_pfamA=pfamA_reg_full.auto_pfamA
			   AND pfamA_reg_full.auto_pfamseq=pfamseq.auto_pfamseq 
			   AND in_full=1
			   AND pfamseq_acc=$qsegment $qbounds);
    
    
    my $ref           = $self->transport->query($query);
    my @features      = ();
    
    for my $row (@{$ref}) {
      
	
	push @features, {
	    'id'     => $row->{'pfamA_id'},
	    'label'  => $row->{'pfamA_id'}."_".$row->{'seq_start'}."-".$row->{'seq_end'},
	    'type'   => "Pfam-A",
	    'method' => "hmmpfam",
	    'start'  => $row->{'seq_start'},
	    'end'    => $row->{'seq_end'},
	    'score'  => $row->{'domain_evalue_score'},
	    'note'   => $row->{'description'},
	    'link'   => "http://www.sanger.ac.uk/cgi-bin/Pfam/getacc?".$row->{'pfamA_acc'},
	    'linktxt' => $row->{'pfamA_id'}
	};
    }

    #now Pfam-Bs
    
    $query         = qq(SELECT pfamB_id, pfamB_acc, md5, seq_start, seq_end 
			FROM   pfamB, pfamB_reg, pfamseq 
			WHERE  pfamB.auto_pfamB=pfamB_reg.auto_pfamB
			AND pfamB_reg.auto_pfamseq=pfamseq.auto_pfamseq
			AND pfamseq_acc=$qsegment $qbounds);

    
    $ref           = $self->transport->query($query);
    for my $row (@{$ref}) {
	
      
	push @features, {
	    'id'     => $row->{'pfamB_id'},
	    'label'  => $row->{'pfamB_id'}."_".$row->{'seq_start'}."-".$row->{'seq_end'},
	    'type'   => "Pfam-B",
	    'method' => "Prodom minus Pfam-A",
	    'start'  => $row->{'seq_start'},
	    'end'    => $row->{'seq_end'},
	    'link'   => "http://www.sanger.ac.uk/cgi-bin/Pfam/pfambget.pl?acc=".$row->{'pfamB_acc'},
	    'link_text' => $row->{'pfamB_id'},
	    
	};
    }
    
    #What other features do we want?

    
    
    return @features;
}





#Pfam also generates its own sequence database, thus we want to serve sequences as well - this is 
sub sequence {
  my ($self, $opts) = @_;
  
  my $segment = $opts->{'segment'};
  
  my $qsegment      = $self->transport->dbh->quote($segment);
  my $query = qq(SELECT sequence, md5
		 FROM pfamseq
		 WHERE pfamseq_acc=$qsegment);
  
  my $row          = shift @{$self->transport->query($query)};
  my $seq = $row->{'sequence'} || "";
  if(defined $opts->{'start'} && defined $opts->{'end'}) {
      $seq = substr($seq, $opts->{'start'}-1, $opts->{'end'}+1-$opts->{'start'});
      
  }
  my $version = $row->{'md5'};
  return {
      'seq'     => $seq,
      'moltype' => 'Protein',
      'version' => $version,
  };
}

1;
