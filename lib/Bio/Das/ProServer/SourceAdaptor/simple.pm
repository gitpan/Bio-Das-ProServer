#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-10-28
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $ $Author: andyjenkinson $
# $Id: simple.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/simple.pm $
#
package Bio::Das::ProServer::SourceAdaptor::simple;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);
use Carp;

our $VERSION = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub capabilities {
  my $ref = {
	     'features'      => '1.0',
	     'feature-by-id' => '1.0',
	     'group-by-id'   => '1.0',
	    };
  return $ref;
}

sub build_features {
  my ($self, $opts) = @_;

  if(defined $opts->{start} ||
     defined $opts->{end}) {
    carp q(Query by start,end is unsupported);
    return;
  }

  my $baseurl = $self->config->{'baseurl'};

  my $args = {
	      'feature_query' => $opts->{'segment'},
	      'fid_query'     => $opts->{'feature_id'},
	      'gid_query'     => $opts->{'group_id'},
	     };

  my @features;
  for my $query (qw(feature_query fid_query gid_query)) {
    my $arg = $args->{$query};
    if(!$arg) {
      next;
    }
    push @features, map {
      {
	type     => $self->config->{'type'},
	method   => $self->config->{'type'},
	segment  => $_->[0],
	id       => $_->[3],
	group_id => $_->[4],
	note     => $_->[1],
	link     => $baseurl.$_->[2],
      };
    } @{$self->transport->query(sprintf $self->config->{$query}, $arg)};
  }

  return @features;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::simple

=head1 VERSION

$LastChangedRevision: 453 $

=head1 SYNOPSIS

Builds das from parser genesat tab-delimited flat files of the form:

 gene.name	gene.id

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 init - Initialise capabilities for this source

  $oSourceAdaptor->init();

=head2 build_features - Return an array of features based on a query given in the config file

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

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

 Bio::Das::ProServer::SourceAdaptor
Carp

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

$Author: Roger Pettett$

=head1 LICENSE AND COPYRIGHT

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
