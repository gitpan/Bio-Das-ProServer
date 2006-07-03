#########
# Author: ek3
# Maintainer: ek3
# Created: 2006-05-14
# Last Modified: 2006-05-24
# Builds DAS features from the datasources uploaded in Ensembl Upload Format version 2 ( see http://www.ensembl.org/http://www.ensembl.org/info/data/external_data/das/EnsemblUploadFormat.pdf
#
package Bio::Das::ProServer::SourceAdaptor::ensembl_upload;

=head1 AUTHOR

Eugene Kulesha <ek3@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

my $MASTER_TABLE = 'journal';
my $DSN_PREFIX = 'hydrasource_';
my $GROUP_PREFIX = 'groups_';

sub init {
    my $self                = shift;
    $self->{'capabilities'} = {
	'features' => '1.0',
	'stylesheet' => '1.0',
    };
}

sub das_stylesheet {
  my ($self, $opts) = @_;
  my $dsn           = $self->{'dsn'};
  (my $jid = $dsn) =~ s/$DSN_PREFIX//;
  my $query = qq{ SELECT css FROM $MASTER_TABLE WHERE id = $jid };
  my $ref = $self->transport->query($query);
  return $ref->[0]->{'css'};
}

sub das_meta {
  my ($self, $opts) = @_;
  my $dsn           = $self->{'dsn'};
  (my $jid = $dsn) =~ s/$DSN_PREFIX//;
  my $query = qq{ SELECT meta FROM $MASTER_TABLE WHERE id = $jid };
  my $ref = $self->transport->query($query);
  return $ref->[0]->{'meta'};
}

sub build_features {
    my ($self, $opts) = @_;
    my $segment       = $opts->{'segment'};
    my $start         = $opts->{'start'};
    my $end           = $opts->{'end'};
    my $dsn           = $self->{'dsn'};
    my $dbtable       = $dsn;

  #########
  # if this is a hydra-based source the table name contains the hydra name and needs to be switched out
  #
    my $hydraname     = $self->config->{'hydraname'};
    if($hydraname) {
	my $basename = $self->config->{'basename'};
	$dbtable =~ s/$hydraname/$basename/;
    }
    
    (my $grouptable = $dsn) =~ s/$DSN_PREFIX/$GROUP_PREFIX/;

    my $gquery         = qq(SELECT groupid,attributes FROM   $grouptable);
    my $gref           = $self->transport->query($gquery);
    
    my $ghash;
    my $SC = '#1#';
    my $CN = '#2#';

    for my $row (@{$gref}) {
	my $gid = $row->{'groupid'};

# Take care of escaped semicolons and colons
	(my $attrs = $row->{'attributes'}) =~ s/\\;/$SC/g;
	$attrs =~ s/\\:/$CN/g;
	
# Now split attributes on semicolon
	my @attributes = split(/;/, $attrs);

	foreach my $attr (@attributes) {
	    my ($key, $value) = split /=/, $attr, 2;
# Remove preceeding and trailing spaces in attribute names
	    $key =~ s/(^\s+)|(\s+$)//g;
	    $key = "group$key";
	    $value =~ s/$SC/\;/g;
	    $value =~ s/$CN/\:/g;
			  
	    if ($key eq 'grouplink') {
		if ($value =~ m!^(.*):"(.*)"!) {
		    $ghash->{$gid}->{$key}->{$2} = $1;
		} else {
		    $ghash->{$gid}->{$key}->{$value} = $value;
		}
	    }elsif ($key eq 'groupnote') {
		push @{$ghash->{$gid}->{$key}}, $value;
	    }elsif ($key eq 'grouptarget') {
		my ($txt, $id, $start, $stop) = split(/:/,$value);
		push @{$ghash->{$gid}->{$key}}, { 'id' => $id, 'start' => $start, 'stop' => $stop, 'target' => $txt};
	    }else {
		$ghash->{$gid}->{$key} = $value;
	    }
	}
    }
	
    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qbounds       = "";
    $qbounds          = qq(AND start <= '$end' AND end >= '$start') if($start && $end);
    my $query         = qq(SELECT featureid,featuretype,method,segmentid,start,end,strand,phase,score,attributes
			 FROM   $dbtable WHERE  segmentid = $qsegment $qbounds);
    my $ref           = $self->transport->query($query);
    my @features      = ();


    for my $row (@{$ref}) {
	my ($start, $end, $strand) = ($row->{'start'}, $row->{'end'}, $row->{'strand'});

	if($start > $end) {
	    ($start, $end) = ($end, $start);
	}

# Take care of escaped semicolons and colons
	(my $attrs = $row->{'attributes'}) =~ s/\\;/$SC/g;
	$attrs =~ s/\\:/$CN/g;
	
# Now split attributes on semicolon
	my @attributes = split(/;/, $attrs);

    
	my $f = {
	    'id'     => $row->{'featureid'},
	    'type'   => $row->{'featuretype'} || $dbtable,
	    'method' => $row->{'method'} || $dbtable,
	    'start'  => $start,
	    'end'    => $end,
	    'ori' => $strand,
	    'score' => $row->{'score'},
	    'phase' => $row->{'phase'},
	    'note' => [],
	    'target' => [],
	};

	foreach my $attr (@attributes) {
	    my ($key, $value) = split /=/, $attr, 2;
# Remove preceeding and trailing spaces in attribute names
	    $key =~ s/(^\s+)|(\s+$)//g;
	    $value =~ s/$SC/\;/g;
	    $value =~ s/$CN/\:/g;
			  
	    if ($key eq 'link') {
		if ($value =~ m!^(.*):"(.*)"!) {
		    $f->{'link'}->{$2} = $1;
		} else {
		    $f->{'link'}->{$value} = $value;
		}
	    }elsif ($key eq 'note') {
		push @{$f->{$key}}, $value;
	    }elsif ($key eq 'target') {
		my ($txt, $id, $start, $stop) = split(/:/,$value);
		push @{$f->{$key}}, { 'id' => $id, 'start' => $start, 'stop' => $stop, 'target' => $txt};
	    }elsif ($key eq 'group') {
		$f->{$key}->{$value} = $ghash->{$value} || {} ;
	    }else {
		$f->{$key} = $value;
	    }
	}

        push @features, $f;
  }
  
  return @features;
}

1;
