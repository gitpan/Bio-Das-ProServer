#########
# Author: jws
# Maintainer: jws
# Created: 2005-04-19
# Last Modified: 2005-10-03 (by dj3)
# Builds DAS features from ProServer mysql database
# schema at eof

package Bio::Das::ProServer::SourceAdaptor::grouped_db;

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
			     'stylesheet' => '1.0',
			    };
}


#######################################################################################################
sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};
  my $shortsegnamehack = defined($self->config->{'shortsegnamehack'})?$self->config->{'shortsegnamehack'}:1; #e.g. 1 (default) or 0


  return if($shortsegnamehack and (CORE::length("$seg") > 4)); #(speedup?) only handle chromosomes or haplotypes
 
  my $qbounds = ($start && $end)?qq(AND start <= $end AND end >= $start):"";
  
  my $query   = qq(SELECT * FROM feature, fgroup
                   WHERE  segment = '$seg' $qbounds
		   AND feature.group_id = fgroup.group_id
                   ORDER BY start); 
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
				'group'		=> $_->{'group_id'},
				'grouptype'	=> $_->{'group_type'},
				'grouplabel'	=> $_->{'group_label'},
				'groupnote'	=> $_->{'group_note'},
				'grouplink'	=> $_->{'group_link_url'},
				'grouplinktxt'	=> $_->{'group_link_text'},
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

