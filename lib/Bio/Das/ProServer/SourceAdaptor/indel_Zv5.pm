#########
# Author: mc2
# Maintainer: mc2
# Created: 2005-11-11
# Builds indel DAS features for the zebrafish assembly Zv5
#
package Bio::Das::ProServer::SourceAdaptor::indel_Zv5;

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

  if ($segment =~ /Zv5\S+\.\d+/){
      return ();
  }
  
  if ($segment !~ /Zv5\S+/){
      return ();
  }
  

  my @features = ();

  my $qbounds = ($start && $end)?qq(AND i.position < $end AND i.position > $start):"";
  my $query = " SELECT i.indel_id indel, position, sequence, type ".
              " FROM seq_region s, indel i".
	      " WHERE s.name = \'$segment\'  $qbounds ".
	      " AND s.seq_region_id = i.seq_region_id ";

   
  
  print STDERR  "\tQUERY: $query\n";  
  

  my $ref = $self->transport->query($query);    
  
 
  my %indel;



  for my $row (@{$ref}) {      

      my $sequence = $row->{sequence};
      my $type = $row->{type};
      my $position = $row->{position};
                  
      my $end = $type eq 'del'?$position:$position+length($sequence)-1;

            
      push @features, {
	  'id'      => $type."/$sequence", 
	  'start'   => $position,
	  'end'     => $end,	  
	  'type'    => $type eq 'del'?'deletion':'insertion',
	  'ori'     => '+',
	  'method'  => 'ssahaSNP',
	  'link'    => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/indel/indel_Zv5?indel=$row->{indel}",
	  'linktxt' => "indel report",

	      
      }
      
      
  }

  return @features;
}


1;

