#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-12-12
# Last Modified: 2003-12-12
#
# Builds simple DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::simpledb;

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

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head1 SYNOPSIS

  Build simple segment:start:stop features from a basic database table structure:

  segmentid,featureid,start,end,type,note,link


  Configure with:
  [mysource]
  adaptor   = simpledb
  transport = dbi
  dbhost    = mysql.example.com
  dbport    = 3308
  dbname    = proserver
  dbuser    = proserverro
  dbpass    = topsecret
  dbtable   = mytable

  Or for SourceHydra use:
  [mysimplehydra]
  adaptor   = simpledb           # SourceAdaptor to clone
  hydra     = dbi                # Hydra implementation to use
  transport = dbi
  basename  = hydra              # dbi: basename for db tables containing servable data
  dbname    = proserver
  dbhost    = mysql.example.com
  dbuser    = proserverro
  dbpass    = topscret

=head1 METHODS

=head2 init : Initialise capabilities for this source

  $oSourceAdaptor->init();

=cut
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features' => '1.0',
			    };
}

=head2 build_features : Return an array of features based on a query given in the config file

  my @aFeatures = $oSourceAdaptor->build_features({
                                                   'segment' => $sSegmentId,
                                                   'start'   => $iSegmentStart, # Optional
                                                   'end'     => $iSegmentEnd,   # Optional
                                                   'dsn'     => $sDSN,          # if used as part of a hydra
                                                  });

=cut
sub build_features {
  my ($self, $opts) = @_;
  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $dsn           = $self->{'dsn'};
  my $dbtable       = $self->config->{'dbtable'} || $dsn;

  #########
  # if this is a hydra-based source the table name contains the hydra name and needs to be switched out
  #
  my $hydraname     = $self->config->{'hydraname'};

  if($hydraname) {
    my $basename = $self->config->{'basename'};
    $dbtable     =~ s/$hydraname/$basename/;
  }

  my @bound      = ($segment);
  my $query      = qq(SELECT segmentid,featureid,start,end,type,note,link
		      FROM   $dbtable
		      WHERE  segmentid = ?);

  if($start && $end) {
    $query .= qq(AND start <= ? AND end >= ?);
    push @bound, ($end, $start);
  }

  my $ref      = $self->transport->query($query, @bound);
  my @features = ();

  for my $row (@{$ref}) {
    my ($start, $end) = ($row->{'start'}, $row->{'end'});
    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    push @features, {
                     'id'     => $row->{'featureid'},
                     'type'   => $row->{'type'} || $dbtable,
                     'method' => $row->{'type'} || $dbtable,
                     'start'  => $start,
                     'end'    => $end,
		     'note'   => $row->{'note'},
		     'link'   => $row->{'link'},
                    };
  }
  return @features;
}

1;
