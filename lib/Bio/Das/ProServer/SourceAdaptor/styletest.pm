#########
# Author: jws
# Maintainer: jws
# Created: 2005-04-20
# Last Modified: 2005-04-20
# Test harness for stylesheets.
# Retrieves stylesheet, parses out feature types, and creates fake features
# with the correct type for each style.

package Bio::Das::ProServer::SourceAdaptor::styletest;

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

################################################################################
sub length { 1;};

################################################################################

sub build_features {
    my ($self, $opts) = @_;
    my $seg     = $opts->{'segment'};
    my $start   = $opts->{'start'};
    my $end     = $opts->{'end'};
    my @features;

    return if(CORE::length($seg) > 2);  # only do this for chromosomes

    my $stylesheet = $self->das_stylesheet;

    # This is a quick hack, so we aren't going to do a full XML parsing
    # of the stylesheet tree here.  Just grab out the id from the TYPE lines:
    # e.g. <TYPE id="segdup:direct_mid_vfar">

    my @types;

    foreach (split ("\n", $stylesheet)){
	next unless /<\s*TYPE/i;
	next unless /id\s*=\s*["']{1}([^"']*)["']{1}/i;
	push @types, $1;
    }

    foreach my $type (@types){

	# workaround for annoying Bio::Das method forcing type to method:type
	my $method = $type;
	$method =~ s/:.*//; # throw away everything after :

	# create a number of features for each type, on each strand:
	#  - overlapping start (by 5% of range)
	#  - 1 bp
	#  - small (5% of range)
	#  - medium-ish (25% of range)
	#  - overlapping end (by 5% of range)
	#
	# All pretty arbitrary, obviously.
	# Adjust the spacing so the features all get a share of the space to
	# try and minimise bumping caused by label overlaps.
   
	my $range = $end - $start;

	foreach my $ori ('+', '-'){	# generate features on both strands

	    my $oldend = $start-100;

	    # overlapping start feature - width is 5% of range
	    my $newend = $start + ($range * 0.05);

	    push @features, $self->feature( $type,
					    $oldend,
					    $newend,
					    $ori,
					    $method
					);

	    $oldend = $newend + ($range * 0.17);	# add spacer

	    # 1 bp feature
	    $newend = $oldend + 1;

	    push @features, $self->feature( $type,
					    $oldend,
					    $newend,
					    $ori,
					    $method
					);

	    $oldend = $newend + ($range * 0.22);	# bigger spacer

	    # small (5% range) feature 
	    $newend = $oldend + ($range * 0.05);
	    push @features, $self->feature( $type,
					    $oldend,
					    $newend,
					    $ori,
					    $method
					);

	    $oldend = $newend + ($range * 0.16);

	    # medium (25% range) feature 
	    $newend = $oldend + ($range * 0.25);
	    push @features, $self->feature( $type,
					    $oldend,
					    $newend,
					    $ori,
					    $method
					);

	    $oldend = $newend + ($range * 0.05);

	    # overlapping end
	    $newend = $end + 100;
	    push @features, $self->feature( $type,
					    $oldend,
					    $newend,
					    $ori,
					    $method
					);
	}
    }      
  return (@features);

}


sub feature {
    my ($self, $type, $start, $end, $ori, $method) = @_;
    return {
		'id'		=> $type,
		'start'		=> $start,
		'end'		=> $end,
		'label'		=> $type,
		'ori'		=> $ori,
		'type'		=> $type,
		'typecategory'	=> 'similarity',
		'method'	=> $method,
	};
}

1;
