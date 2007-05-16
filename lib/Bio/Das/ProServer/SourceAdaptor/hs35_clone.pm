#########
# Author:        avc
# Maintainer:    avc
# Created:       2004-02-05
# Last Modified: 2005-06-03 rmp
# Builds DAS features for clone sets available in Ensembl
#
package Bio::Das::ProServer::SourceAdaptor::hs35_clone;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2004 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use Data::Dumper;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'      => '1.0',
			     'feature-by-id' => '1.0',
			     'types' 	     => '1.0',
			     'entry_points'  => '1.0',
			    };

  # create a segment (in this case chromosome) cache:
  my $seg_length_cache = {};
  my $seg_name_cache   = {};
  my $seg_id_cache     = {};
  # +---------------+------+-----------------+-----------+
  # | seq_region_id | name | coord_system_id | length    |
  # +---------------+------+-----------------+-----------+
  # |        965059 | 5    |               1 | 181034922 |
  # +---------------+------+-----------------+-----------+
  # +-----------------+-------------+---------+------+--------------------------------+
  # | coord_system_id | name        | version | rank | attrib                         |
  # +-----------------+-------------+---------+------+--------------------------------+
  # |               1 | chromosome  | NCBI34  |    1 | default_version                |
  # |               2 | supercontig | NULL    |    2 | default_version                |
  # |               3 | clone       | NULL    |    3 | default_version                |
  # |               4 | contig      | NULL    |    4 | default_version,sequence_level |
  # +-----------------+-------------+---------+------+--------------------------------+
  my $query = qq(SELECT sr.name,
                        sr.length,
                        sr.seq_region_id AS srid
                 FROM   seq_region sr,
                        coord_system cs
		 WHERE  sr.coord_system_id = cs.coord_system_id
		 AND    cs.name            = "chromosome");

  my $ref = $self->transport->query($query);

  for my $row (@{$ref}) {
    $seg_id_cache->{$row->{'name'}}     = $row->{'srid'};
    $seg_length_cache->{$row->{'name'}} = $row->{'length'};
  }

  $self->segment_id_cache($seg_id_cache);
  $self->segment_length_cache($seg_length_cache);

  my $query2 = qq(SELECT version AS segver
                  FROM   coord_system
		  WHERE  name = "chromosome");

  my $ref2 = $self->transport->query($query2);
  #print Dumper($ref2);
  for my $row (@{$ref2}) {
    my $ver = $row->{'segver'};
    #$ver =~ s/NCBI//;
    $self->segment_version($ver);
  }

  if (! $self->segment_version() ){
    $self->segment_version("1.0");
  }
}

###################################################################################
sub build_entry_points {
  my ($self) = @_;

  my @ep;
  for my $c ( $self->known_segments()) {
    push (@ep, {
		'segment'  => $c,
		'length'   => $self->{'_seg_length_cache'}->{$c},
		'version'  => $self->segment_version(),
		'subparts' => "yes",
	       }
	 );
  }

  return(@ep);
}

###################################################################################
sub segment_id_cache {
  my ($self, $var) = @_;
  if ($var) {
    $self->{'_seg_id_cache'} = $var;
  }
  return($self->{'_seg_id_cache'});
}

###################################################################################
sub segment_length_cache {
  my ($self, $var) = @_;
  if ($var) {
    $self->{'_seg_length_cache'} = $var;
  }
  return($self->{'_seg_length_cache'});
}

###################################################################################
sub segment_version {
  my ($self, $var) = @_;
  if ($var) {
    $self->{'_segment_version'} = $var;
  }
  return($self->{'_segment_version'});
}

###################################################################################
sub known_segments {
  my ($self) = @_;

  return( keys ( %{$self->{'_seg_length_cache'}} ) );
}

###################################################################################
sub build_features {
  my ($self, $opts) = @_;

  if ($opts->{'feature_id'}){
    return ($self->build_features_by_id($opts));

  } elsif ($opts->{'segment'}) {
    return($self->build_features_by_segment($opts));

  } else {
    print STDERR "unsupported feature fetch request!\n";
    return();
  }
}

###################################################################################
sub build_features_by_segment  {
  my ($self, $opts) = @_;

  my $seg = $opts->{'segment'};
  my ($end,$start);

  unless ( $opts->{'end'} ) {
    $end = $self->segment_length_cache->{$seg};
  } else {
    $end = $opts->{'end'};
  }

  unless ( $opts->{'start'} ){
    $start = 1;
  } else {
    $start = $opts->{'start'};
  }

  ($start, $end) = ($end, $start) if($start > $end);

  my $chr_srid = $self->segment_id_cache->{$seg};

  my $query = qq(SELECT ma.value             AS feature_id,
                        mf.misc_feature_id   AS mfid,
                        mf.seq_region_start  AS start,
                        mf.seq_region_end    AS end,
                        mf.seq_region_strand AS ori,
                        ms.name              AS type
		 FROM   misc_feature          mf,
                        seq_region            sr,
                        misc_feature_misc_set mfms,
                        misc_set              ms,
                        misc_attrib           ma,
                        attrib_type           at
		 WHERE  (mf.seq_region_end  between $start AND $end
		   OR    mf.seq_region_start between $start AND $end)
		 AND    sr.seq_region_id   = '$chr_srid'
		 AND    mf.seq_region_id   = sr.seq_region_id
		 AND    mf.misc_feature_id = mfms.misc_feature_id
		 AND    mfms.misc_set_id   = ms.misc_set_id
		 AND    ms.misc_set_id     > 1
                 AND    mf.misc_feature_id = ma.misc_feature_id
                 AND    ma.attrib_type_id  = at.attrib_type_id 
                 AND    at.code            )
		 ."IN("
		 .join(",",map{"'$_'"}defined($self->{config}{types})?split(/\s+/,$self->{config}{types}):qw(clone_name name non_ref synonym well_name))
        	 .")";      

  my $ref = $self->transport->query($query);

  my @features = ();

  for my $row (@{$ref}) {
    my $start = $row->{'start'};
    my $end   = $row->{'end'};

    next if ($row->{'type'} =~ /gap/i); # ignore gap features

    ($start, $end) = ($end, $start) if($start > $end);

    my $ori   = "+";
    if ($row->{'ori'} == -1) {
      $ori = "-";
    }

    $self->length($self->segment_length_cache->{$seg}); # set the length of the current segment

    push @features, {
		     'segment'  	=> $seg,
		     'id'       	=> $row->{'feature_id'},
		     'type'     	=> $row->{'type'},
		     'method'   	=> $row->{'type'},
		     'segment_start'  	=> 1,
		     'segment_end'    	=> $self->segment_length_cache->{$seg},
		     'start'    	=> $start,
		     'end'      	=> $end,
		     'ori'    		=> $ori,
		     'segment_version'  => $self->segment_version(),
		    };
  }

  return @features;
}

###################################################################################
sub build_features_by_id {
  my ($self, $opts) = @_;
  my $cloneid       = $opts->{'feature_id'};
  $cloneid          =~ s/(\w+)\.\d+/$1/; # remove any version number

  # mysql> select * from attrib_type;
  # +----------------+-----------------+-------------------------------+-----------------------------------------+
  # | attrib_type_id | code            | name                          | description                             |
  # +----------------+-----------------+-------------------------------+-----------------------------------------+
  # |              1 | synonym         | Alternate names for clone     | Synonyms                                |
  # |              2 | FISHmap         | FISH information              | FISH map                                |
  # |              3 | organisation    | Organisation sequencing clone |                                         |
  # |              4 | state           | Current state of clone        |                                         |
  # |              5 | BACend_flag     | BAC end flags                 |                                         |
  # |              6 | embl_acc        | EMBL accession number         |                                         |
  # |              7 | superctg        | Super contig id.              |                                         |
  # |              8 | seq_len         | Accession length              |                                         |
  # |              9 | fp_size         | FP size                       |                                         |
  # |             10 | note            | Note                          |                                         |
  # |             11 | positioned_by   | Positioned by                 |                                         |
  # |             12 | bac_acc         | BAC end accession             |                                         |
  # |             13 | plate           | Plate                         |                                         |
  # |             20 | bac_start       | Start of BAC                  |                                         |
  # |             21 | bac_end         | End of BAC                    |                                         |
  # |             22 | location        | Location in well plate        |                                         |
  # |             23 | start_pos       | Start positioned by           |                                         |
  # |             24 | end_pos         | End positioned by             |                                         |
  # |             25 | mismatch        | Mismatch                      |                                         |
  # |             26 | name            | Name                          |                                         |
  # |             27 | type            | Type of feature               |                                         |
  # |             28 | htg_phase       | HTG Phase                     | High Throughput Genome Phase            |
  # |             29 | toplevel        | Top Level                     | Top Level Non-Redundant Sequence Region |
  # |             30 | GeneCount       | Gene Count                    | Total Number of Genes                   |
  # |             31 | KnownGeneCount  | Known Gene Count              | Total Number of Known Genes             |
  # |             32 | PseudoGeneCount | PseudoGene Count              | Total Number of PseudoGenes             |
  # |             33 | SNPCount        | SNP Count                     | Total Number of PseudoGenes             |
  # +----------------+-----------------+-------------------------------+-----------------------------------------+
  # mysql> select * from misc_attrib where misc_feature_id = 2000000;
  # +-----------------+----------------+-------------+
  # | misc_feature_id | attrib_type_id | value       |
  # +-----------------+----------------+-------------+
  # |         2000001 |             26 | RP11-125B08 |
  # |         2000001 |             27 | BAC         |
  # +-----------------+----------------+-------------+
  # mysql> select * from misc_feature where misc_feature_id = 2000000;
  # +-----------------+---------------+------------------+----------------+-------------------+
  # | misc_feature_id | seq_region_id | seq_region_start | seq_region_end | seq_region_strand |
  # +-----------------+---------------+------------------+----------------+-------------------+
  # |         2000000 |        965059 |        114484726 |      114638021 |                 1 |
  # +-----------------+---------------+------------------+----------------+-------------------+
  # mysql> select * from seq_region where seq_region_id = 965059;
  # +---------------+------+-----------------+-----------+
  # | seq_region_id | name | coord_system_id | length    |
  # +---------------+------+-----------------+-----------+
  # |        965059 | 5    |               1 | 181034922 |
  # +---------------+------+-----------------+-----------+
  # mysql> select * from misc_set;
  # +-------------+----------+--------------+-------------+------------+
  # | misc_set_id | code     | name         | description | max_length |
  # +-------------+----------+--------------+-------------+------------+
  # |           1 | ntctgs   | NT contigs   |             |  100600000 |
  # |           2 | tilepath | Tilepath     |             |     500000 |
  # |           4 | cloneset | 1Mb cloneset |             |     300000 |
  # |           8 | gap      | gaps         |             |   22000000 |
  # |          16 | tp32k    | 32K cloneset |             |     500000 |
  # +-------------+----------+--------------+-------------+------------+
  # mysql> describe misc_feature_misc_set;
  # +-----------------+----------------------+------+-----+---------+-------+
  # | Field           | Type                 | Null | Key | Default | Extra |
  # +-----------------+----------------------+------+-----+---------+-------+
  # | misc_feature_id | int(10) unsigned     |      | PRI | 0       |       |
  # | misc_set_id     | smallint(5) unsigned |      | PRI | 0       |       |
  # +-----------------+----------------------+------+-----+---------+-------+

  my $query = qq(SELECT DISTINCT mf.seq_region_start  AS start,
                                 mf.seq_region_end    AS end,
                                 mf.seq_region_strand AS ori,
                                 sr.name              AS chr,
                                 ms.name              AS type
		 FROM   misc_attrib ma,
                        attrib_type mt,
                        misc_feature mf,
                        seq_region sr,
                        misc_set ms,
                        misc_feature_misc_set msmf
		 WHERE  ma.value           = '$cloneid'
		 AND    ma.attrib_type_id  = mt.attrib_type_id
		 AND    mt.name	           = 'Name'
		 AND    ma.misc_feature_id = mf.misc_feature_id
		 AND    mf.seq_region_id   = sr.seq_region_id
		 AND    mf.misc_feature_id = msmf.misc_feature_id
		 AND    msmf.misc_set_id   = ms.misc_set_id);

  my $ref = $self->transport->query($query);

  my @features = ();

  for my $row (@{$ref}) {
    my $start      = $row->{'start'};
    my $end        = $row->{'end'};
    ($start, $end) = ($end, $start) if($start > $end);
	
    my $ori   = "+";
    if ($row->{'ori'} == -1) {
      $ori = "-";
    }

    my $chr = $row->{'chr'};
    $self->length($self->segment_length_cache->{$chr}); # set the length of the current segment

    push @features, {
		     'segment'         => $chr,
		     'id'              => $cloneid,
		     'type'            => $row->{'type'},
		     'method'          => $row->{'type'},
		     'segment_start'   => 1,
		     'segment_end'     => $self->segment_length_cache->{$chr},
		     'start'           => $start,
		     'end'             => $end,
		     'ori'    	       => $ori,
		     'segment_version' => $self->segment_version(),
		    };
  }

  return @features;
}

###################################################################################
sub length {
  my ($self, $var) = @_;
  if ($var) {
    $self->{'_length'} = $var;
  }
  return($self->{'_length'});
}

###################################################################################
sub build_types {
  my @tmp;
	
  foreach ("Tilepath", "1Mb clone set", "37K cloneset", "32K cloneset") {
    push (@tmp,
	  {
	   'method'	=> "ensembl",
	   'category'	=> "default",
	   'type'	=> $_,
	  },
	 );
  }
  return (@tmp);
}
1;
