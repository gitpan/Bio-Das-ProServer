#########
# Author: rmp
# Maintainer: rmp
# Created: 2004-02-16
# Last Modified: 2006-05-12
# Builds DAS features from Gene Trap database
# Updated for nw DB schema and stylesheet support (avc)
# 2006-05-12 jws Changed way links work, so only ini file has to be changed to
# add, change, or remove links.  Allows multiple simultaneous versions and 
# removes need for CVS & server updates just to fix a link.

package Bio::Das::ProServer::SourceAdaptor::genetrap;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

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

#######################################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

#######################################################################################################
sub length { 1;};

#######################################################################################################
sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};

  return if(CORE::length("$seg") > 2);

  #+--------------------+-------------------------------------------------------------------------------------------------+------+-----+---------+-------+
  #| Field              | Type                                                                                            | Null | Key | Default | Extra |
  #+--------------------+-------------------------------------------------------------------------------------------------+------+-----+---------+-------+
  #| match_id           | int(10) unsigned                                                                                |      |     | 0       |       |
  #| cell_line_id       | varchar(25)                                                                                     |      |     |         |       |
  #| ann_method         | enum('no_hits','exon','intron','genomic','poor_seq')                                            | YES  |     | NULL    |       |
  #| ann_category       | enum('EST','gene')                                                                              | YES  |     | NULL    |       |
  #| unique_match       | enum('unique','multiple')                                                                       | YES  |     | NULL    |       |
  #| ensembl_gene_id    | varchar(20)                                                                                     | YES  |     | NULL    |       |
  #| source_ens_gene_id | enum('MapTag','BLAST')                                                                          | YES  |     | NULL    |       |
  #| hit_chr            | enum('1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','X') | YES  | MUL | NULL    |       |
  #| hit_strand         | enum('1','-1')                                                                                  | YES  |     | NULL    |       |
  #| hit_start          | int(10) unsigned                                                                                | YES  | MUL | NULL    |       |
  #| hit_end            | int(10) unsigned                                                                                | YES  | MUL | NULL    |       |
  #| blast_refseq_id    | varchar(10)                                                                                     | YES  |     | NULL    |       |
  #| blast_sense        | enum('+','-')                                                                                   | YES  |     | NULL    |       |
  #| blast_evalue       | float                                                                                           | YES  |     | NULL    |       |
  #| genbank_acc        | varchar(10)                                                                                     | YES  |     | NULL    |       |
  #| dna_type           | varchar(20)                                                                                     | YES  |     | NULL    |       |
  #| sequence           | blob                                                                                            | YES  |     | NULL    |       |
  #| date_posted        | varchar(20)                                                                                     | YES  |     | NULL    |       |
  #| vector             | varchar(50)                                                                                     | YES  | MUL | NULL    |       |
  #| source             | varchar(20)                                                                                     | YES  | MUL | NULL    |       |
  #| gene_id            | int(10) unsigned                                                                                | YES  | MUL | 0       |       |
  #| trace_id           | varchar(50)                                                                                     | YES  |     | NULL    |       |
  #+--------------------+-------------------------------------------------------------------------------------------------+------+-----+---------+-------+

  #   0 | CL459132    | cDNA     | <sequence here>          | Mar 29 2004  | pGT0lxr | SIGTR  |    NULL | NULL     |
  #| 10 | AD0873      | exon     | gene                     | unique       | NULL    | NULL   |         | 1        |       
  # 956 |      1020 | NM_133243  | -           |         

  my $qbounds = ($start && $end)?qq(AND hit_start <= $end AND hit_end >= $start):"";
  my $table_name = $self->config->{'tablename'};
  
  my $query   = qq(SELECT cell_line_id       AS id,
                          hit_start          AS start,
                          hit_end            AS end,
                          hit_strand         AS ori,
                          blast_sense        AS blast_ori,
                          ensembl_gene_id AS type,
                          ensembl_gene_id    AS note,
                          source             AS source,
                          vector             AS vector,
						  source_ens_gene_id AS method
		   		   FROM   $table_name
                   WHERE  hit_chr = '$seg'
				   AND das_type   = 'public'
		           $qbounds
                   ORDER BY hit_start
				   );

  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
	
	# dynamic links from ini
	# ini file should contain link entries like:
	# link_sigtr = http://some_cgi_url/browser?cell_line_id=#### 
	#
	# Everything will be lowercased for matching, and spaces in the feature
	# source will be converted to underscores.
	# e.g. link_stanford_wl will match a source of 'Stanford WL'
	# 
	# if a link_default is defined, it will be used for missing 
	# sources.
	#

  	my $id = $_->{'id'};
	my $source = $_->{'source'};
	$source =~ s/ /_/g;

	my $link_source = lc($source);
	
	my $link_url = $self->config->{"link_${link_source}"};
	$link_url = $self->config->{"link_default"} unless $link_url;	
	$link_url =~ s/\#\#\#\#/$id/;		

	my $method = $_->{'method'} || "MapTag";
	my $vector = $_->{'vector'} || "default";
	$vector =~ s/"//g;   # some vectors like:  """pGT0,1,2"""

	$method = $method . ":" . $vector;
	
	my $ori = $_->{'ori'} || $_->{'blast_ori'} || "+";
	if ($ori == 1 ){
		$ori = "+";
	} elsif ($ori == -1 ) {
		$ori = "-";
	}
		
  	push @results, 
    				{
    				  'id'      => $_->{'id'},
    				  'type'    => sprintf("%s", "genetrap:$source" || "genetrap:default"),
			      'typecategory'=> "similarity",
    				  'method'  => $method,
    				  'start'   => $_->{'start'},
    				  'end'     => $_->{'end'},
    				  'ori'     => $ori,
    				  'link'    => $link_url,
    				  'linktxt' => "Genetrap info",
    				  'note'    => $_->{'note'},
    				};

  }
  
  return (@results);

}
