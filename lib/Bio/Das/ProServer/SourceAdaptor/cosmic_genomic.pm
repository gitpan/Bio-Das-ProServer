#########
# Author: jc3
# Maintainer: $Author: rmp $
# Created: 2003-06-20
# Last Modified: $Date: 2006/07/03 10:05:07 $
# Provides DAS features for COSMIC genes.

package Bio::Das::ProServer::SourceAdaptor::cosmic_genomic;

=head1 AUTHOR

Jody Clements <jc3@sanger.ac.uk>.

based on modules by 

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init{
  my $self = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
  $self->{'genelink'} = "http://www.sanger.ac.uk/perl/genetics/CGP/cosmic?action=bygene;locus_name=";
  $self->{'mutlink'} = "http://www.sanger.ac.uk/perl/genetics/CGP/cosmic?action=mut_summary;id=";
  $self->{'linktxt'} = "more information";
}

sub length{
       return 1;
}

sub build_features{
  my ($self,$opts) = @_;
  my $segid    = $opts->{'segment'};
  my $start    = $opts->{'start'};
  my $end      = $opts->{'end'};

 my @features = ();
  if ($segid !~ /^(10|20|(1?[1-9])|(2?[12])|[XY])$/i){
    return @features;
  }
  
  $segid =~ s/X/23/; 
  $segid =~ s/Y/24/; 
  
  my $boundary = "";
  $boundary = qq(AND gf.genome_start <= '$end' AND gf.genome_stop >= '$start') if (defined $start && defined $end);
  
#Gene footprints 
               
  my $query = qq(SELECT gf.genome_start as START_POSITION,
                        gf.genome_stop as STOP_POSITION,
                        gsom.gene_name as NAME,
                        gf.strand as ORI,
                        gsom.swissprot_accession as SPID
              FROM    genomic_feature gf,
                      gene_som gsom
              WHERE   gf.chromosome = '$segid'
              AND     gsom.id_gene = gf.id
              $boundary
              AND     gf.id_feature_type = 2);

  my $ref = $self->transport->query($query);

  for my $row (@{$ref}) {
    my $start  = $row->{'START_POSITION'};
    my $end    = $row->{'STOP_POSITION'};
    my $name   = $row->{'NAME'};
    my $spid   = $row->{'SPID'}||undef;
    my $url = $self->{'genelink'};
    my $link = $url . $name;
    my $strand = $row->{'ORI'}||0;
    ($start, $end) = ($end, $start) if ($start > $end);


    my $data = {
	        'id'     => $name,
		'type'   => "cosmic:gene",
                'typecategory' => 'cosmic',
		'start'  => $start,
		'end'    => $end,
	        'link'   => $link,
	        'linktxt' => $self->{'linktxt'},
                'ori'  => $strand,
               };
    $data->{'note'} = "SwissProt ID : $spid" if ($spid);            
    push @features, $data;                     
  }

#Mutation points
  $query = qq(SELECT  gf.genome_start as START_POSITION,
                      gf.genome_stop as STOP_POSITION,
                      sm.id_mutation as ID,
                      sm.cds_mut_syntax as SYN
              FROM    genomic_feature gf,
                      sequence_mutation sm
              WHERE   gf.chromosome = '$segid'
              $boundary
              AND     gf.id = sm.id_mutation
              AND     gf.id_feature_type = 1);              

  $ref = $self->transport->query($query);
  
# Counts - the following query will count the total number of 
#         mutations at a single point on the genome. This is 
#         not the number of times the visible mutation occured,
#         but all mutations at that point. (BUG/FEATURE)
         
  my $count_query = qq(SELECT  gf.genome_start as START_POSITION, 
                               count(gsm.id_mutation) as MUT_COUNT
                       FROM    gene_sample_mutation gsm,
                               genomic_feature gf
                       WHERE   gf.chromosome = '$segid'
                       AND     gf.id_feature_type = 1
                       $boundary
                       AND     gf.id = gsm.id_mutation
                       GROUP BY gf.genome_start);

  my %count_ref = map {$_->{'START_POSITION'},$_->{'MUT_COUNT'} } 
                        @{$self->transport->query($count_query)};

  for my $row (@{$ref}) {
    my $start  = $row->{'START_POSITION'};
    my $end    = $row->{'STOP_POSITION'};
    my $name   = $row->{'SYN'} || $row->{'ID'};
    my $spid   = $row->{'SPID'}||undef;
    my $url = $self->{'mutlink'};
    my $link = $url . $row->{'ID'};
    my $count = $count_ref{$row->{'START_POSITION'}}||0;
    my $type = 'cosmic:mutation';
    $type .= ":big" if ($count > 10);
    ($start, $end) = ($end, $start) if($start > $end);
    

    my $data = {
	        'id'     => $name,
		'type'   => $type,
                'typecategory' => 'cosmic',
		'start'  => $start,
		'end'    => $end,
	        'link'   => $link,
	        'linktxt' => $self->{'linktxt'},
                'note'    => "$count mutations at this point",
               };
    push @features, $data;                     
  }
  $self->transport->disconnect();  
  return @features;
}

1;
