#########
# Author: am3
# Maintainer: $Author: rmp $
# Created: 2007-04-25
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Provides DAS features for COSMIC mutations.

package Bio::Das::ProServer::SourceAdaptor::cosmic_ncbi_36_mutations;

use strict;
use Data::Dumper;
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

  my @subTypes = qw(10 13 28 29);
  my @insTypes = qw(11 30);
  my @delTypes = qw(12 31);

  my @features = ();
  if ($segid !~ /^(10|20|(1?[1-9])|(2?[12])|[XY])$/i){
    return @features;
  }
  
  $segid =~ s/X/23/; 
  $segid =~ s/Y/24/;
  
  my $mutSql;
  
  if(defined($start) && defined($end)){
    $mutSql = qq( SELECT g.GENOME_START, g.GENOME_STOP, g.STRAND, g.ID, m.ID_MUT_TYPE, m.CDS_MUT_SYNTAX, m.AA_MUT_SYNTAX, count(gsm.ID_MUTATION) as OCCURS
                  FROM  SEQUENCE_MUTATION m
                  join GENOMIC_FEATURE g on m.ID_MUTATION = g.ID and g.ID_FEATURE_TYPE = 1
                  join GENE_SAMPLE_MUTATION gsm on m.ID_MUTATION = gsm.ID_MUTATION
                  where g.GENOME_VERSION = 36
                  and g.CHROMOSOME = $segid
                  and g.GENOME_START <= $end
                  and g.GENOME_STOP >= $start
                  group by g.GENOME_START, g.GENOME_STOP, g.STRAND, g.ID, m.ID_MUT_TYPE, m.CDS_MUT_SYNTAX, m.AA_MUT_SYNTAX
                  order by count(gsm.ID_MUTATION) DESC);
 
  } else {
    $mutSql = qq( SELECT g.GENOME_START, g.GENOME_STOP, g.STRAND, g.ID, m.ID_MUT_TYPE, m.CDS_MUT_SYNTAX, m.AA_MUT_SYNTAX, count(gsm.ID_MUTATION) as OCCURS
                  FROM  SEQUENCE_MUTATION m
                  join GENOMIC_FEATURE g on m.ID_MUTATION = g.ID and g.ID_FEATURE_TYPE = 1
                  join GENE_SAMPLE_MUTATION gsm on m.ID_MUTATION = gsm.ID_MUTATION
                  where g.GENOME_VERSION = 36
                  and g.CHROMOSOME = $segid
                  group by g.GENOME_START, g.GENOME_STOP, g.STRAND, g.ID, m.ID_MUT_TYPE, m.CDS_MUT_SYNTAX, m.AA_MUT_SYNTAX
                  order by count(gsm.ID_MUTATION) DESC);
  }

  my $ans = $self->transport->query($mutSql);
  my $count = 0;
  my $prevOccurs = 0;
  foreach my $row(@$ans){
    $count++;
    my ($fstart,$fend);
    if($row->{'STRAND'} eq '+'){
      $fstart = $row->{'GENOME_START'};
      $fend = $row->{'GENOME_START'};
    } else {
      $fstart = $row->{'GENOME_STOP'};
      $fend = $row->{'GENOME_STOP'};
    }
    my $occurs = $row->{'OCCURS'};
    my $note = "CDS-syntax:".$row->{'CDS_MUT_SYNTAX'}."&nbsp;&nbsp;&nbsp;AA-syntax:".$row->{'AA_MUT_SYNTAX'}."&nbsp;&nbsp;&nbsp;Observed $occurs times";
    my $mutType = $row->{'ID_MUT_TYPE'};
    my $type = 'default';
    my $catagory = 'default';
    
    if(grep(m/^$mutType/,@subTypes)){
      $type = 'substitution';
    }
    
    if(grep(m/^$mutType/,@delTypes)){
      $type = 'deletion';
    }
    
    if(grep(m/^$mutType/,@insTypes)){
      $type = 'insertion';
    }
        
    my $url = 'http://www.sanger.ac.uk/perl/genetics/CGP/cosmic?action=mut_summary&id=' .  $row->{'ID'};
    
    push(@features,{
             'id'   => $row->{'ID'},
             'label'=> $row->{'CDS_MUT_SYNTAX'},
             'type'   => $type,
             'typecatagory' => $catagory,
             'start'  => $fstart,
		         'end'    => $fstart,
		         'note'   => $note,
		         'ori'    => $row->{'STRAND'},
		         'link'   => $url,
		         'linktxt'=>'view in Cosmic'});
    
    if($count==1){  
      $prevOccurs = $occurs;  
    }
  }
  
  return @features;
} 

sub das_stylesheet{
  my ($self) = @_;

  my $response = qq(<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="default">
    <TYPE id="default">
      <GLYPH>
        <BOX>
          <FGCOLOR>blue</FGCOLOR>
          <FONT>sanserif</FONT>
          <BGCOLOR>blue</BGCOLOR>
        </BOX>
      </GLYPH>
    </TYPE>
    <TYPE id="substitution">
      <GLYPH>
        <CROSS>
          <FGCOLOR>blue</FGCOLOR>
          <FONT>sanserif</FONT>
          <BGCOLOR>blue</BGCOLOR>
        </CROSS>
      </GLYPH>
    </TYPE>
    <TYPE id="deletion">
      <GLYPH>
        <TRIANGLE>
          <DIRECTION>S</DIRECTION>
          <POINT>1</POINT>
          <FGCOLOR>blue</FGCOLOR>
          <FONT>sanserif</FONT>
          <BGCOLOR>blue</BGCOLOR>
        </TRIANGLE>
      </GLYPH>
    </TYPE>
    <TYPE id="insertion">
      <GLYPH>
        <TRIANGLE>
          <DIRECTION>N</DIRECTION>
          <POINT>1</POINT>
          <FGCOLOR>blue</FGCOLOR>
          <FONT>sanserif</FONT>
          <BGCOLOR>blue</BGCOLOR>
        </TRIANGLE>
      </GLYPH>
    </TYPE>
  </CATEGORY> 
</STYLESHEET>
</DASSTYLE>\n);

  return $response;
}


1;
