#########
# Author: jws
# Maintainer: jws
# Created: 2005-05-13
# Last Modified: 2005-05-13
# Builds DAS features from ProServer mysql database
# Customised for "GeneDAS" features (i.e. segment=gene id, no start/end)
# schema at eof

package Bio::Das::ProServer::SourceAdaptor::gene_pro_db;

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

#######################################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			    };
}

#######################################################################################################
sub length { 1;};

#######################################################################################################
sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};

  my $query   = qq(SELECT * FROM feature
                   WHERE  segment = '$seg'
		   );
  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
  	push @results, {
				'id'		=> $_->{'id'},
				'start'		=> $_->{'start'},
				'end'		=> $_->{'end'},
				'label'		=> $_->{'label'},
				'score'		=> $_->{'score'},
				'ori'		=> $_->{'orient'},
				'phase'		=> $_->{'phase'},
				'type'		=> $_->{'type_id'},
				'typecategory'	=> $_->{'type_category'},
				'method'	=> $_->{'method'},
				'target_start'	=> $_->{'target_start'},
				'target_stop'	=> $_->{'target_end'},
				'target_id'	=> $_->{'target_id'},
				'link'		=> $_->{'link_url'},
				'linktxt'	=> $_->{'link_text'},
				'note'		=> $_->{'note'},
			};

  }
  
  return (@results);

}

1;

# SCHEMA
# Generic MySQL schema to hold DAS feature data for ProServer
#	
#	feature
#		id		varchar(30)	
#		label		varchar(30)
#		segment		varchar(30)
#		start		int(11)
#		end		int(11)
#		score		float
#		orient		enum('0', '+', '-')
#		phase		enum('0','1','2')
#		type_id		varchar(30)
#		type_category	varchar(30)
#		method		varchar(30)
#		group_id	varchar(30)
#		target_id	varchar(30)
#		target_start	int(11)
#		target_end	int(11)
#		link_url	varchar(255)
#		link_text	varchar(30)
#		note		text
#		
#	group
#		group_id	varchar(30)
#		label		varchar(30)
#		type		varchar(30)
#		note		text
#		link_url	varchar(255)
#		link_text	varchar(30)
#	
#	Note that spec allows multiple groups, targets, and links per feature,
#	but these aren't implemented here.
#	

