#########
# Author: mc2
# Maintainer: mce
# Created: Fri Oct  8 09:55:10 BST 2004
# Last Modified: 
# Builds indel DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::indel_Zv4;

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

  
  my $query = " SELECT i.indel_id indel, position, sequence, type ".
              " FROM seq_region s, indel i".
	      " WHERE s.name = \'$segment\' AND i.position < $end AND i.position > $start ".
	      " AND s.seq_region_id = i.seq_region_id ";

   
  my $ref = $self->transport->query($query);    
  
 
  my %indel;

  for my $row (@{$ref}) {      

      my $sequence = $row->{sequence};
      my $type = $row->{type};
      my $position = $row->{position};
                  
      my $end = $type eq 'del'?$position:$position+length($sequence)-1;

      
      push @features, {
	  'id'      => $type.":$sequence", 
	  'start'   => $position,
	  'end'     => $end,	  
	  'type'    => $type eq 'del'?'deletion':'insertion',
	  'ori'     => 0,
	  'method'  => 'ssahaIndel',
	  'link'    => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/indel/indel_Zv4?indel=$row->{indel}",
	  'linktxt' => "indel report",
	  'typecategory' => "indel_Zv4",
	      
      }
      
      
  }

  return @features;
}


1;

