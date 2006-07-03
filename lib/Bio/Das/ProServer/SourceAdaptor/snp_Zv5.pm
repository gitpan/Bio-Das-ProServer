#########
# Author: mc2
# Maintainer: mc2
# Created: 2005-11-15
# Builds snp DAS features for the zebrafish assembly Zv5
#
package Bio::Das::ProServer::SourceAdaptor::snp_Zv5;

=head1 AUTHOR

Mario Caccamo <mc2@sanger.ac.uk>.

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

sub build_features {
  my ($self, $opts) = @_;

  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};

  #print STDERR "\tREQUEST seq:$segment st:$start end:$end\n";
  
  
  if ($segment =~ /Zv5\S+\.\d+/){
      #print STDERR "\t\tsegment is chunk\n";
      return ();
  }
  
  if ($segment !~ /Zv5\S+/){     
      #print STDERR "\t\t $segment segment is not scaffold\n";
      return ();
  }
  

  my @features = ();

  if (not defined $start or not defined $end){
      #print STDERR "coordinates not defined\n";
      return @features;
  }

  
  my $query = " SELECT i.snp_id snp, position,scaffold_base, trace_base".
              " FROM seq_region s, snp i".
	      " WHERE s.name = \'$segment\' AND i.position < $end AND i.position > $start ".
	      " AND s.seq_region_id = i.seq_region_id ";

   
  
  #print STDERR  "\tQUERY: $query\n";  
  

  my $ref = $self->transport->query($query);    
  
 
  for my $row (@{$ref}) {      

      my $sequence = $row->{sequence};  
      my $position = $row->{position};     

                  
      my $end = $position;

      
      push @features, {
	  'id'      => $row->{scaffold_base}."/".$row->{trace_base}, 
	  'start'   => $position,
	  'end'     => $position,	  
	  #'type'    => $type eq 'del'?'deletion':'insertion',
	  'ori'     => '+',
	  'method'  => 'ssahaSNP',
	  'link'    => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/snp/snp_Zv5?snp=$row->{snp}",
	  'linktxt' => "snp report",	
	      
      }
      
      
  }

  return @features;
}


1;

