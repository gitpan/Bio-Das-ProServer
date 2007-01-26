#########
# Author: avc
# Maintainer: avc
# Created: 2004-02-05
# Last Modified: 2004-02-05
# Builds DAS features for Human Spectral Genomics cloneset from mapping database
#
package Bio::Das::ProServer::SourceAdaptor::gtfdb;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2004 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use Data::Dumper;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'      => '1.0',
			     'feature-by-id' => '1.0',
			     'types' 	     => '1.0',
			    };
  

}


###################################################################################
sub build_features {
  my ($self, $opts) = @_;
  
  if ($opts->{'feature_id'}){
    return ($self->build_features_by_id($opts));

  } elsif ($opts->{'segment'}) {
    return($self->build_features_by_segment($opts));

  } else {
    print STDERR "unsupported feature fetch request!\n";
    return();
  }
}

  

###################################################################################
sub build_features_by_segment  {
  my ($self, $opts) = @_;

  my $seg = $opts->{'segment'};
  my ($end,$start);
  
  #print STDERR Dumper($opts);
  
  if ( $opts->{'end'} && ! $opts->{'start'}) {
    print STDERR "no segment start in segment request!\n";
    return();
  } elsif ( $opts->{'start'} && ! $opts->{'end'})  {
    print STDERR "no segment end in segment request!\n";
    return();
  }
  
  my $table_name = $self->config->{'tablename'};
  my $query;
  if ($opts->{'start'} && $opts->{'end'}){
  	$start = $opts->{'start'};
  	$end = $opts->{'end'};
    ($start, $end) = ($end, $start) if($start > $end);
    $query = qq(SELECT DISTINCT
			 id,
			 chr,
			 start,
			 end,
			 orientation as ori,
			 type
			 FROM  $table_name
			 WHERE chr= "$seg" 
			 AND start <= $end 
			 AND end >= $start);
  } else {
    $query = qq(SELECT DISTINCT
			 id,
			 chr,
			 start,
			 end,
			 orientation as ori,
			 type
			 FROM  $table_name
			 WHERE chr = "$seg");
  
  }
  
  my $ref = $self->transport->query($query);
  
  my @features = ();
  
  for my $row (@{$ref}) {
    my $start = $row->{'start'};
    my $end   = $row->{'end'};
    ($start, $end) = ($end, $start) if($start > $end);
    
    my $chr = $row->{'chr'};

    push @features, {
		     'segment'         => $chr,
		     'id'              => $row->{'id'},
		     'type'            => $row->{'type'} . ":ssaha2",
		     'method'          => $row->{'type'} . ":ssaha2",
		     'segment_start'   => $opts->{'start'},
		     'segment_end'     => $opts->{'end'},
		     'start'           => $start,
		     'end'             => $end,
		     'ori'    	       => $row->{'ori'},
		     'segment_version' => 1,
		    };
  }

  return @features;
}

###################################################################################
sub build_features_by_id  {
  my ($self, $opts) = @_;
  my $cloneid = $opts->{'feature_id'};
  #$cloneid    =~ s/(\w+)\.\d+/$1/; # remove any version number

  my $table_name = $self->config->{'tablename'};
  
  my $query = qq(SELECT DISTINCT
			 id,
			 chr,
			 start,
			 end,
			 orientation as ori,
			 type
			 FROM  $table_name
		 WHERE    id LIKE "$cloneid%"
		 GROUP BY start);

  my $ref = $self->transport->query($query);

  my @features = ();

  for my $row (@{$ref}) {
    my $start = $row->{'start'};
    my $end   = $row->{'end'};
    ($start, $end) = ($end, $start) if($start > $end);
    
    my $chr = $row->{'chr'};
    $self->length(1); # set the length of the current segment
    
    push @features, {
		     'segment'         => $chr,
		     'id'              => $row->{'id'},
		     'type'            => $row->{'type'} . ":ssaha2",
		     'method'          => $row->{'type'} . ":ssaha2",
		     'segment_start'   => 1,
		     'segment_end'     => 1,
		     'start'           => $start,
		     'end'             => $end,
		     'ori'    	       => $row->{'ori'},
		     'segment_version' => 1,
		    };
  }
  
  return @features;
}

###################################################################################
sub length {
  my ($self, $var) = @_;
  $self->{'_length'} ||= $var;
  return($self->{'_length'});
}

###################################################################################
sub build_types {

  return ({
	   'method'   => "ssaha2",
	   'category' => "default",
	   'type'     => "spectral_genomics_clone",
	  },
	  {
	   'method'   => "ssaha2",
	   'category' => "default",
	   'type'     => "spectral_genomics_clone",
	  },
	 );
}
1;
