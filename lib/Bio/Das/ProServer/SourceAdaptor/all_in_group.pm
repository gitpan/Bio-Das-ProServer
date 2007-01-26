#########
# Author: jws
# Maintainer: jws, dj3
# Created: 2005-04-19
# Last Modified: 2006-10-06 (by dj3)
#
# Returns all features in groups represented in the range.
# First fetches all groups represented in the range, then retrieves all
# features in those groups.  Features outside the range are hacked to be one bp
# features on the edge of the range, with a style of hidden.
#
# All this is so that grouped DAS displays can draw group lines to features
# 'off the edge' off the display
#
# schema at eof


package Bio::Das::ProServer::SourceAdaptor::all_in_group;

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};
  my $shortsegnamehack = defined($self->config->{'shortsegnamehack'})?$self->config->{'shortsegnamehack'}:1; #e.g. 1 (default) or 0

  return if($shortsegnamehack and (CORE::length("$seg") > 4));#(speedup?) only handle chromosomes or haplotypes

  # To include group members that are outside the range of the request, first
  # pull back the groups that are within the range, and then retrieve all the
  # features in those groups.
  
  $seg=$self->transport->dbh->quote($seg);
  my $qbounds="";
  if(defined $start && defined $end){
    $qbounds = qq(AND start <= ).$self->transport->dbh->quote($end).qq( AND end >= ).$self->transport->dbh->quote($start);
  }

  my $query   = qq(SELECT group_id FROM feature
                   WHERE  segment = $seg $qbounds); 

  my @groups = @{$self->transport->query($query)};

  return unless @groups;

  my $groupstring = " AND feature.group_id in (";
  @groups = map ("'".$_->{'group_id'}."'", @groups);
  $groupstring .= join (",", @groups);
  $groupstring .= ") ";

  $query   = qq(SELECT * FROM feature, fgroup
                   WHERE  segment = $seg $groupstring
		   AND feature.group_id = fgroup.group_id
                   ORDER BY start); 
  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
  	my $fstart = $_->{'start'};
  	my $fend = $_->{'end'};
	my $type = $_->{'type_id'};
	my $method = $_->{'method'};

	#fake features outside the range - das code will filter these otherwise
	if ($fend < $start){ 
		$fend = $fstart = $start; 
		$type = "$method:hidden";
	}
	if ($fstart > $end){
		$fend = $fstart = $end;
		$type = "$method:hidden";
	}
	
  	push @results, {
				'id'		=> $_->{'id'},
				'start'		=> $fstart,
				'end'		=> $fend,
				'label'		=> $_->{'label'},
				'score'		=> $_->{'score'},
				'ori'		=> $_->{'orient'},
				'phase'		=> $_->{'phase'},
				'type'		=> $type,
				'typecategory'	=> $_->{'type_category'},
				'method'	=> $method,
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
#		group_label	varchar(30)
#		group_type	varchar(30)
#		group_note	text
#		group_link_url	varchar(255)
#		group_link_text	varchar(30)
#	
#	Note that spec allows multiple groups, targets, and links per feature,
#	but these aren't implemented here.
#	

