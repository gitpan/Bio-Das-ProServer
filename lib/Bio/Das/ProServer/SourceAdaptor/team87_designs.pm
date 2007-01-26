#########
# Author: vvi, dj3
# Maintainer: vvi
# Created: 2006-10-05
# Last Modified: 2006-10-11 (by dj3)
# Builds  DAS features from team 87 MIG oracle database
# Hacked from grouped_db
# See Sanger RT tickets 5567 and 12795
# Was formerly "eucomm_constructs" adaptor.

package Bio::Das::ProServer::SourceAdaptor::team87_designs;

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
  my $label   = $self->config->{'label'};
  my $shortsegnamehack = defined($self->config->{'shortsegnamehack'})?$self->config->{'shortsegnamehack'}:1; #e.g. 1 (default) or 0


  return if($shortsegnamehack and (CORE::length("$seg") > 4)); #(speedup?) only handle chromosomes or haplotypes
 
  $seg=$self->transport->dbh->quote($seg);
  my $qbounds="";
  if(defined $start && defined $end){
    $start=$self->transport->dbh->quote($start);
    $end=$self->transport->dbh->quote($end);
    $qbounds = qq(AND feature_start <= $end AND feature_end >= $start);
  }
  
  my $query   = qq(SELECT * FROM display_feature, chromosome_dict
                   WHERE display_feature.chr_id = chromosome_dict.chr_id 
		   AND name = $seg
		   $qbounds
                ); 
  $query .= " AND label=".$self->transport->dbh->quote($label) if defined($label);
  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
  	push @results, {
				'id'		=> $_->{'DISPLAY_FEATURE_ID'},
				'start'		=> $_->{'FEATURE_START'},
				'end'		=> $_->{'FEATURE_END'},
				#'label'		=> $_->{'DISPLAY_FEATURE_TYPE'},
				#'score'		=> $_->{'score'},
				'ori'		=> $_->{'FEATURE_STRAND'},
				#'phase'		=> $_->{'phase'},
				'type'		=> $_->{'DISPLAY_FEATURE_TYPE'},
				#'typecategory'	=> $_->{'type_category'},
				#'method'	=> $_->{'method'},
				'group'		=> $_->{'DISPLAY_FEATURE_GROUP'},
				#'grouptype'	=> $_->{'group_type'},
				#'grouplabel'	=> $_->{'group_label'},
				#'groupnote'	=> $_->{'group_note'},
				#'grouplink'	=> $_->{'group_link_url'},
				#'grouplinktxt'	=> $_->{'group_link_text'},
				#'target_start'	=> $_->{''},
				#'target_stop'	=> $_->{'target_end'},
				#'target_id'	=> $_->{'target_id'},
				#'link'		=> $_->{'link_url'},
				#'linktxt'	=> $_->{'link_text'},
				#'note'		=> $_->{'note'},
			};

  }
  
  return (@results);

}

1;
