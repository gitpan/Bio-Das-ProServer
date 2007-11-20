#########
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2003-05-20
# Last Modified: $Date: 2007/11/20 20:12:21 $
#
# Builds DAS features from parsed interpro entries served from SRS
#
package Bio::Das::ProServer::SourceAdaptor::interpro_mole;

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

sub init {
  my $self = shift;
  $self->{'capabilities'} = {
			     'features' => '1.0',
			     'types'    => '1.0',
			    };
  $self->{'_length'} = {};
}

sub length {
  my ($self, $seg) = @_;
  #########
  # force initialisation of the transport (so that mole.ini is loaded)
  #
  my $dbh      = $self->transport->dbh();
  my $config   = $self->config();
  my $uniprot  = $config->{'uniprot'}  || 'undef';
  my $mushroom = $config->{'mushroom'} || 'undef';
  my $entry_id = '';

  if(!$self->{'_length'}->{$seg}) {
    #########
    # First try accession: P35458
    #
    my $ref = $self->transport->query(qq(SELECT entry_id
                                         FROM   $uniprot.accession
                                         WHERE  accession=?), $seg);

    if(scalar @$ref) {
      $entry_id = $ref->[0]->{'entry_id'};

    } else {
      #########
      # Next try id: DYNA_CHICK
      #
      my $ref = $self->transport->query(qq(SELECT entry_id
                                           FROM   $uniprot.entry e
                                           WHERE  e.name=?), $seg);
      if(scalar @$ref) {
	$entry_id = $ref->[0]->{'entry_id'};
      }
    }

    $ref = $self->transport->query(qq(SELECT sequence_length FROM $uniprot.entry WHERE entry_id=?), $entry_id);
    if(scalar @$ref) {
      $self->{'_length'}->{$seg} = $ref->[0]->{'sequence_length'};
    }
  }

  return $self->{'_length'}->{$seg} || 1;
}

sub build_types {
  my ($self, $opts) = @_;
  my $seg   = $opts->{'segment'};
  my @types = ();

  if($seg) {
    my %typecount = ();
    map { $typecount{$_->{'type'}}++ } $self->build_features($opts);
    @types = sort { $b->{'count'} <=> $a->{'count'} } map {
      $_ = {
	    'type'  => $_,
	    'count' => $typecount{$_},
	   };
    } keys %typecount;
  }
  return @types;
}

sub build_features {
  my ($self, $opts) = @_;
  my $seg = $opts->{'segment'};

  $self->{'_features'}->{$seg} ||= [];

  #########
  # force initialisation of the transport (so that mole.ini is loaded)
  #
  my $dbh = $self->transport->dbh();

  if(scalar @{$self->{'_features'}->{$seg}} == 0) {
    my $config    = $self->config();
    my $uniprot   = $config->{'uniprot'}  || 'undef';
    my $mushroom  = $config->{'mushroom'} || 'undef';
    my $accession = '';

    if($seg !~ /^IPR/) {

      #########
      # First try accession: P35458
      #
      my $ref = $self->transport->query(qq(SELECT accession
                                           FROM   $uniprot.accession
                                           WHERE  accession=?), $seg);

      if(scalar @$ref) {
	$accession = $ref->[0]->{'accession'};
	
      } else {
	#########
	# Next try id: DYNA_CHICK
	#
	my $ref = $self->transport->query(qq(SELECT accession
                                             FROM   $uniprot.accession a,
                                                    $uniprot.entry e
                                             WHERE  a.entry_id = e.entry_id
                                             AND    e.name=?), $seg);
	if(scalar @$ref) {
	  $accession = $ref->[0]->{'accession'};
	}
      }
    }

    my $interpro_keys = [];
    if($accession) {
      my $ref = $self->transport->query(qq(SELECT interpro_key
                                           FROM   $mushroom.uniprot2interpro
                                           WHERE  uniprot_accession=?), $accession);
      if(scalar @$ref) {
	$interpro_keys = [map { $_->{'interpro_key'} } @$ref];
      }
    } else {
      $interpro_keys = [map {
	$_->{'interpro_key'}
      } @{$self->transport->query(qq(SELECT interpro_key
                                     FROM   $mushroom.uniprot2interpro
                                     WHERE  interpro_id=?), $seg)}];
    }

    if(scalar @$interpro_keys) {
      my $query = qq(SELECT iprm.match_id       AS id,
                            iprm.match_id       AS group_id,
                            iprm.match_db_name  AS type,
                            iprm.match_db_name  AS method,
                            iprm.match_name     AS note,
                            iprm.location_start AS start,
                            iprm.location_end   AS end,
                            meta.url            AS url
                     FROM      $mushroom.iprmatches    iprm
                     LEFT JOIN $mushroom.interpro_meta meta ON meta.dbname = iprm.match_db_name
                     WHERE  interpro_key IN(@{[join(',', map { $dbh->quote($_) } @$interpro_keys)]}));
      $self->{'_features'}->{$seg} = $self->transport->query($query);
    }
  }

  #########
  # map in dbxref links
  #
  my $tmp = $self->{'_features'}->{$seg} || [];

  for my $feature (@$tmp) {
    if($feature->{'url'} && $feature->{'url'} ne '-') {
      $feature->{'link'} ||= {};
      $feature->{'link'}->{sprintf($feature->{'url'}, $feature->{'id'})} = $feature->{'type'};
    }
  }

  return @$tmp;
}

1;
