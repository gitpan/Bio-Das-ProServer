#########
# Author: jws
# Maintainer: jws, dj3
# Created: 2005-04-19
# Last Modified: $Date: 2007/11/20 20:12:21 $ $Author: rmp $
# Id:            $Id: grouped_db.pm,v 2.70 2007/11/20 20:12:21 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor/grouped_db.pm,v $
# $HeadURL$
# Builds DAS features from ProServer mysql database
# schema at eof

package Bio::Das::ProServer::SourceAdaptor::grouped_db;

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);
our $VERSION  = do { my @r = (q$Revision: 2.70 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

#######################################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
                             'entry_points'  => '1.0',
			     'types' =>'1.0',
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
 
  $seg=$self->transport->dbh->quote($seg);
  my $qbounds="";
  if(defined $start && $start ne"" && defined $end && $end ne""){
#  if(defined $start  && defined $end){
    $start=$self->transport->dbh->quote($start);
    $end=$self->transport->dbh->quote($end);
    $qbounds = qq(AND start <= $end AND end >= $start);
  }

  my $query   = qq(SELECT * FROM feature, fgroup
                   WHERE  segment = $seg $qbounds
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

sub build_types {
	my $self = shift;
	if(@_){
		my @r=();
		foreach(@_){
			my ($seg,$start,$end)=@{$_}{qw(segment start end)};
			$seg=$self->transport->dbh->quote($seg);
			my $qbounds="";
			if(defined $start && $start ne"" && defined $end && $end ne""){
				$start=$self->transport->dbh->quote($start);
				$end=$self->transport->dbh->quote($end);
				$qbounds = qq(AND start <= $end AND end >= $start);
			}
			my $query   = qq(SELECT DISTINCT type_id type, method FROM feature
					WHERE  segment = $seg $qbounds);
			push @r,map{$_->{segment}=$seg; @{$_}{qw(start end)}=($start,$end)if $qbounds; $_}@{$self->transport->query($query)};
		}
		return @r;
	}else{
		my $query   = qq(SELECT DISTINCT type_id type, method FROM feature);
		return @{$self->transport->query($query)};	
	}
}
sub build_entry_points {
  my ($self) = @_;
  my $query   = qq(SELECT DISTINCT segment FROM feature);
  return map{$_->{subparts}="no"; $_->{version}=$self->{config}{assembly}if exists $self->{config}{assembly} ;$_}@{$self->transport->query($query)};
}
sub segment_version{
	my $self=shift; 
	return exists($self->{config}{assembly})?$self->{config}{assembly}:undef;
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

