#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2007-01-04
# Last Modified: $Date: 2007/01/26 23:10:41 $ $Author: rmp $
#
# HUGO-based data mapped via Ensembl
# Contact me if you'd like the loader-script used to download, map and insert data into this schema.
#
package Bio::Das::ProServer::SourceAdaptor::hugo;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 DATABASE SCHEMA

/* feature id, chromosome, start, stop, textual description */
 CREATE TABLE `hugo36` (
   `name` char(20) NOT NULL default '',
   `chr` char(2) NOT NULL default '',
   `chr_start` bigint(20) unsigned NOT NULL,
   `chr_end` bigint(20) unsigned NOT NULL,
   `description` varchar(255) NOT NULL default '',
   PRIMARY KEY  (`name`)
 ) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/* external database types and base urls containing placeholders for sprintf */
 CREATE TABLE `hugo36_external` (
   `external_type` smallint(5) unsigned NOT NULL,
   `name` char(32) NOT NULL default '',
   `url` varchar(255) NOT NULL default '',
   PRIMARY KEY  (`external_type`)
 ) ENGINE=MyISAM DEFAULT CHARSET=latin1;

 /* join-table between features (hugo36.name) and external database types (hugo36_external.external_type) */
 CREATE TABLE `hugo36_xref` (
   `name` char(20) NOT NULL default '',
   `external_type` smallint(5) unsigned NOT NULL,
   `external_id` char(32) NOT NULL default '',
   UNIQUE KEY `name` (`name`,`external_type`,`external_id`)
 ) ENGINE=MyISAM DEFAULT CHARSET=latin1;

=cut
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);

our $VERSION         = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };
our $TABLESET        = 'hugo36';
our $UNBOUNDED_QUERY = qq(SELECT name,chr_start,chr_end,description
                          FROM   $TABLESET
                          WHERE  chr = ?);
our $BOUNDED_QUERY   = qq($UNBOUNDED_QUERY
                          AND    chr_start <= ?
                          AND    chr_end   >= ?);
our $XREF_QUERY      = qq(SELECT x.external_id,
                                 e.name,
                                 e.url
                          FROM   ${TABLESET}_xref     x,
                                 ${TABLESET}_external e
                          WHERE  x.name          = ?
                          AND    x.external_type = e.external_type);
our $MAX_INTENSITIES = 4; # (zero-based)

=head1 METHODS

=head2 init : Configure capabilities for this source

  $oHUGOSourceAdaptor->init();

=cut
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

=head2 build_features : Construct features from database queries based on segment and optionally start, end

  my @aFeatures = $oHUGOSourceAdaptor->build_features({
                                                       'segment' => 1,
                                                       'start'   => 23423524,
                                                       'end'     => 34509374,
                                                      });

=cut
sub build_features {
  my ($self, $opts) = @_;
  $opts           ||= {};
  my $segment       = $opts->{'segment'};
  my $start         = $opts->{'start'};
  my $end           = $opts->{'end'};
  my $query         = '';
  my @args          = ($segment);

  if($start && $end) {
    $query = $BOUNDED_QUERY;
    push @args, ($end, $start);

  } else {
    $query = $UNBOUNDED_QUERY;
  }

  my $ref       = $self->transport->query($query, @args);
  my @features  = ();
  my $links     = {};
  my $maxweight = 0;

  for my $row (@{$ref}) {
    #########
    # Load xrefs for this gene
    #
    my $xref = $self->transport->query($XREF_QUERY, $row->{'name'});
    $links->{$row->{'name'}} = { map {
      sprintf($_->{'url'}, $_->{'external_id'}) => sprintf("%s:%s", $_->{'name'}, $_->{'external_id'});
    } @$xref };

    #########
    # track the max number of xrefs to calculate styles / intensities
    #
    my $count  = scalar @$xref;
    $maxweight = $count if($count > $maxweight);
  }

  for my $row (@{$ref}) {
    my $weight    = scalar keys %{$links->{$row->{'name'}}};
    my $relweight = int($MAX_INTENSITIES*$weight/$maxweight);
    push @features, {
                     'id'           => $row->{'name'},
                     'type'         => "hugo:$relweight",
                     'method'       => 'hugo',
		     'typecategory' => 'hugo',
                     'start'        => $row->{'chr_start'},
                     'end'          => $row->{'chr_end'},
		     'note'         => $row->{'description'},
		     'link'         => $links->{$row->{'name'}},
                    };
  }
  return @features;
}

1;
