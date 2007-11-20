#########
# Author: am3
# Maintainer: $Author: rmp $
# Created: 2007-04-24
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Provides DAS features for COSMIC transcripts.

package Bio::Das::ProServer::SourceAdaptor::cosmic_ncbi_36_transcripts;

use strict;
use Data::Dumper;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init{
  my $self = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
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
  
  my $transcriptSql;
  
  if(defined($start) && defined($end)){
    $transcriptSql = qq(SELECT distinct t.ID_TRANSCRIPT, t.ACCESSION_NUMBER, g.GENE_NAME
                        FROM TRANSCRIPT t
                        join GENE_SOM g on t.ID_GENE = g.ID_GENE
                        join TRANSCRIPT_EXONS te on t.ID_TRANSCRIPT = te.ID_TRANSCRIPT
                        join GENOMIC_FEATURE gf on te.ID_EXON = gf.ID and gf.ID_FEATURE_TYPE = 3
                        where gf.GENOME_VERSION = 36
                        and gf.CHROMOSOME = $segid
                        and gf.GENOME_START <= $end
                        and gf.GENOME_STOP >= $start);
  } else {
    $transcriptSql = qq(SELECT distinct t.ID_TRANSCRIPT, t.ACCESSION_NUMBER, g.GENE_NAME
                        FROM TRANSCRIPT t
                        join GENE_SOM g on t.ID_GENE = g.ID_GENE
                        join TRANSCRIPT_EXONS te on t.ID_TRANSCRIPT = te.ID_TRANSCRIPT
                        join GENOMIC_FEATURE gf on te.ID_EXON = gf.ID and gf.ID_FEATURE_TYPE = 3
                        where gf.GENOME_VERSION = 36
                        and gf.CHROMOSOME = $segid);
  }
  
  my $transAns = $self->transport->query($transcriptSql);
  
  foreach my $trow (@$transAns) {
    my $tid = $trow->{'ID_TRANSCRIPT'};
    my $acc = $trow->{'ACCESSION_NUMBER'};
    my $gname = $trow->{'GENE_NAME'};
    
    my $label = $gname.':'.$acc;
    
    my $exonSql = qq(select te.ID_EXON, te.EXON_NUMBER ,gf.GENOME_START, gf.GENOME_STOP, gf.STRAND
                  from GENOMIC_FEATURE gf
                  join TRANSCRIPT_EXONS te on te.ID_EXON = gf.ID and gf.ID_FEATURE_TYPE = 3
                  where te.ID_TRANSCRIPT = $tid
                  and gf.GENOME_VERSION = 36
                  order by te.EXON_NUMBER);
   
    my $exonAns = $self->transport->query($exonSql);
    
    my $url =  'http://www.sanger.ac.uk/perl/genetics/CGP/cosmic?action=gene&ln=' . $gname;
       
    foreach my $erow(@$exonAns){
      my $exonNo = $erow->{'EXON_ORDER'};
      my $id = "$acc:exon$exonNo";
      my $fstart = $erow->{'GENOME_START'};
      my $fend = $erow->{'GENOME_STOP'};
      
      my $type = 'cosmic:exon';
      
      if ($fend < $start){ 
		    $fend = $fstart = $start; 
		    $type = "cosmic:exon:hidden";
	    }
	    if ($fstart > $end){
		    $fend = $fstart = $end;
		    $type = "cosmic:exon:hidden";
	    }
	   
      push(@features,{
              'id'     => $id,
              'label'   => $exonNo,
              'grouplabel'	=> $label,
              'group_id'		=> $label,
              'group_type'  => 'cosmic:transcript',
              'type'   => $type,
              'start'  => $fstart,
		          'end'    => $fend,
		          'ori'    => $erow->{'STRAND'},
		          'grouplink'   => $url,
		          'grouplinktxt'=> 'view in Cosmic'});
    }
  }
   
  return @features;
} 

1;
