#########
# Maintainer: dj3
# Created: 2005-11-11
# Last Modified: 2005-11-21 (by dj3)
# Builds DAS features from a mysql database containing scores for experiments and strandless locations
# schema at eof

package Bio::Das::ProServer::SourceAdaptor::simplescore_db;

=head1 AUTHOR

David Jackson <dj3@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);


sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}


sub das_stylesheet {
  my $self = shift;
  my $i=0;
  return (qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="microarray">).join("",map {qq(
    <TYPE id="clone_).$i++.qq(">
      <GLYPH>
        <BOX>
          <FGCOLOR>$_</FGCOLOR>
          <FONT>sanserif</FONT>
          <BUMP>0</BUMP>
          <BGCOLOR>$_</BGCOLOR>
        </BOX>
      </GLYPH>
    </TYPE>) } ("black", map{$_->{"colour"}} $self->getThresholdsColours)).qq(
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>\n));
}


sub segment_version(){my ($self, $seg) = @_; return $1 if $seg=~/\.(\d+)$/; return "1.0"}

sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $shortsegnamehack = defined($self->config->{'shortsegnamehack'})?$self->config->{'shortsegnamehack'}:1; #e.g. 1 (default) or 0
  return if($shortsegnamehack and (CORE::length("$seg") > 4)); #(speedup?) only handle chromosomes or haplotypes

  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};
  my $expid=$self->getExpId;
 
  my $qbounds = ($start && $end)?qq(AND start <= $end AND end >= $start):"";  
  my $query   = qq(SELECT * FROM feature JOIN data USING (feature_id)
                   WHERE  segment = '$seg' $qbounds
		   AND data.experiment_id='$expid'
                   ORDER BY start); 

  my @thresholdinfo = $self->getThresholdsColours;
  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
	my $score=$_->{'score'};
	my $ti=0;
	foreach (@thresholdinfo){ if ($score >= $_->{'lowerlimit'}){$ti++;} else{last;}}
  	push @results, {
				'id'		=> $_->{'feature_id'},
				'start'		=> $_->{'start'},
				'end'		=> $_->{'end'},
				'score'		=> $score,
				'type'		=> "clone_".$ti,
				'typecategory'	=> "microarray",
				'method'	=> $expid,
				'note'		=> $_->{'note'},
			};

  }
  
  return (@results);
}


sub getExpId($){
  my $self = shift;
  if ($self->config->{'hydra'}) {
    return substr($self->dsn,CORE::length($self->config->{'hydraname'}));
  }else{
    return $self->config->{'experiment_id'};
  }
}

###
#get colours for thresholds (per experiement if thresholds table contains experiment_id)
sub getThresholdsColours($){
  my $self = shift;
  my $query   = qq(SELECT * FROM thresholds
                   ORDER BY lowerlimit);
  my %hashByExpId=();
  foreach (@{$self->transport->query($query)}){push @{$hashByExpId{$_->{'experiment_id'}||""}},$_}
  my $expid = $self->getExpId;
  return @{$hashByExpId{$expid}} if(exists($hashByExpId{$expid}));
  return @{$hashByExpId{""}} if(exists($hashByExpId{""}));
  return ();
}

1;

### example commands to create db....
#mysql> create database emt_35_mhc_mtp;
#mysql> use emt_35_mhc_mtp;
#mysql> CREATE TABLE thresholds (lowerlimit FLOAT  NOT NULL, colour VARCHAR(20)  NOT NULL, experiment_id varchar(30), KEY(lowerlimit), KEY(experiment_id));
#mysql> CREATE TABLE data (feature_id varchar(30) NOT NULL, experiment_id varchar(30) NOT NULL, score float default NULL, UNIQUE KEY joint_key (experiment_id,feature_id));
#mysql> CREATE TABLE feature (feature_id varchar(30) NOT NULL, segment varchar(30) NOT NULL, start int(11) unsigned NOT NULL default 0, end int ( 11 ) unsigned NOT NULL default 0, UNIQUE KEY feature_id_key ( feature_id ) , KEY segment_key ( segment,start,end ) );

### SCHEMA
#mysql> show tables;
#+--------------------------+
#| Tables_in_emt_35_mhc_mtp |
#+--------------------------+
#| data                     |
#| feature                  |
#| thresholds               |
#+--------------------------+
#3 rows in set (0.00 sec)
#mysql> describe data;
#+---------------+-------------+------+-----+---------+-------+
#| Field         | Type        | Null | Key | Default | Extra |
#+---------------+-------------+------+-----+---------+-------+
#| feature_id    | varchar(30) |      | PRI |         |       |
#| experiment_id | varchar(30) |      | PRI |         |       |
#| score         | float       | YES  |     | NULL    |       |
#+---------------+-------------+------+-----+---------+-------+
#3 rows in set (0.00 sec)
#mysql> describe feature;
#+------------+------------------+------+-----+---------+-------+
#| Field      | Type             | Null | Key | Default | Extra |
#+------------+------------------+------+-----+---------+-------+
#| feature_id | varchar(30)      |      | PRI |         |       |
#| segment    | varchar(30)      |      | MUL |         |       |
#| start      | int(11) unsigned |      |     | 0       |       |
#| end        | int(11) unsigned |      |     | 0       |       |
#+------------+------------------+------+-----+---------+-------+
#4 rows in set (0.02 sec)
#mysql> describe thresholds;
#+---------------+-------------+------+-----+---------+-------+
#| Field         | Type        | Null | Key | Default | Extra |
#+---------------+-------------+------+-----+---------+-------+
#| lowerlimit    | float       |      | MUL | 0       |       |
#| colour        | varchar(20) |      |     |         |       |
#| experiment_id | varchar(30) | YES  | MUL | NULL    |       |
#+---------------+-------------+------+-----+---------+-------+
#3 rows in set (0.00 sec)

