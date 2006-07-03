#########
# Author: rmp
# Maintainer: rmp
# Created: 2003-10-28
# Last Modified: 2003-10-28
#
# Builds das from parser genesat tab-delimited flat files of the form:
# gene.name\tgene.id
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
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self = shift;
  $self->{'capabilities'} = {
			     'features'      => '1.0',
			     'feature-by-id' => "1.0",
			     'group-by-id'   => "1.0",
			    };
}

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
