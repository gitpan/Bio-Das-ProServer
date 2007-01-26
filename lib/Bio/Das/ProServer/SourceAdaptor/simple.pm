#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-10-28
# Last Modified: $Date: 2007/01/26 23:10:41 $ $Author: rmp $
#
package Bio::Das::ProServer::SourceAdaptor::simple;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);

our $VERSION = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head1 SYNOPSIS

Builds das from parser genesat tab-delimited flat files of the form:

 gene.name	gene.id

=head1 METHODS

=head2 init : Initialise capabilities for this source

  $oSourceAdaptor->init();

=cut
sub init {
  my $self = shift;
  $self->{'capabilities'} = {
			     'features'      => '1.0',
			     'feature-by-id' => '1.0',
			     'group-by-id'   => '1.0',
			    };
}

=head2 build_features : Return an array of features based on a query given in the config file

  my @aFeatures = $oSourceAdaptor->build_features({
                                                   'segment'    => $sSegmentId,
                                                   'start'      => $iSegmentStart, # Optional
                                                   'end'        => $iSegmentEnd,   # Optional
                                                  });
  my @aFeatures = $oSourceAdaptor->build_features({
                                                   'feature_id' => $sFeatureId,
                                                  });

  my @aFeatures = $oSourceAdaptor->build_features({
                                                   'group_id'   => $sGroupId,
                                                  });

=cut
sub build_features {
  my ($self, $opts) = @_;

  return if(defined $opts->{'start'} || defined $opts->{'end'});

  my $baseurl = $self->config->{'baseurl'};

  my $args = {
	      'feature_query' => $opts->{'segment'},
	      'fid_query'     => $opts->{'feature_id'},
	      'gid_query'     => $opts->{'group_id'},
	     };

  my @features;
  for my $query (qw(feature_query fid_query gid_query)) {
    my $arg = $args->{$query};
    push @features, map {
      $_ = {
	    'type'     => $self->config->{'type'},
	    'method'   => $self->config->{'type'},
	    'segment'  => @{$_}[0],
	    'id'       => @{$_}[3],
	    'group_id' => @{$_}[4],
	    'note'     => @{$_}[1],
	    'link'     => $baseurl.@{$_}[2],
	   };
    } @{$self->transport->query(sprintf($self->config->{$query}, $arg))};
  }

  return @features;
}

1;
