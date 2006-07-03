#########
# Author: mc2
# Maintainer: mc2
# Created: Wed Oct  6 12:28:15 BST 2004
# Last Modified:
# Builds snp DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::snp_Zv4;

=head1 AUTHOR

Mario Caccamo <mc2@sanger.ac.uk>.

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

sub build_features {
  my ($self, $opts) = @_;

  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  
  if ($segment =~ /Zv4\S+\.\d+/){ #segment is chunk
      return ();
  }
  
  if ($segment !~ /Zv4\S+/){ #segment is not scaffold
      return ();
  }
  

  my @features = ();

  if (not defined $start or not defined $end){ #coordinates not defined
      return @features;
  }

  
  my $query = " SELECT i.snp_id snp, position, context".
              " FROM seq_region s, snp i".
	      " WHERE s.name = \'$segment\' AND i.position < $end AND i.position > $start ".
	      " AND s.seq_region_id = i.seq_region_id ";

   
  
  my $ref = $self->transport->query($query);    
 
  for my $row (@{$ref}) {      

      my $sequence = $row->{sequence};  
      my $position = $row->{position};     

                  
      my $end = $position;

      
      push @features, {
	  'start'   => $position,
	  'end'     => $position,	  	
	  'ori'     => 0,
	  'method'  => 'ssahaIndel',
	  'link'    => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/snp/snp_Zv4?snp=$row->{snp}",
	  'linktxt' => "snp report",
	      
      }
            
  }

  return @features;
}

1;

