#########
# Author: ?
# Maintainer: dj3 (but only because this field was empty)
# Last Modified: 24-10-2006
# 

package Bio::Das::ProServer::SourceAdaptor::pig_ends_all_35;


=head1 AUTHOR

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut



use strict;

use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);


sub init {
  my $self = shift;
  $self->{'capabilities'} = {
                             'features' => '1.0',
			     'stylesheet' => '1.0',
			 };

  $self->{'link'}    = ["http://www.sanger.ac.uk/cgi-bin/Projects/S_scrofa/WebFPCreport.cgi?mode=wfcreport&name=","http://pre.ensembl.org/Sus_scrofa/cytoview?mapfrag="];
  $self->{'linktxt'} = ["Clone_report","Pig Pre"];


}

sub length{

    0;
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
          <FGCOLOR>lightpink3</FGCOLOR>
          <FONT>sanserif</FONT>
          <BGCOLOR>lightpink3</BGCOLOR>
        </BOX>
      </GLYPH>
    </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>\n);

  return $response;
}


sub build_features{

  my ($self,$opts) = @_;
  
  my $segid   = $opts->{'segment'};  #chr
  my $start   = $opts->{'start'};    #start
  my $end     = $opts->{'end'};      #end
  my $table   = $self->config->{'tablename'};

  if ($segid !~ /(10|20|(1?[1-9])|(2?[12])|[XY])/i ){
      #get contig coordinates
      return;
  }
  
  my @features = ();
  if (!$end){
      return @features;
  }
  
  
  my @qxtras  = ();
  push @qxtras, qq(chr   =  '$opts->{'segment'}')   if(defined $opts->{'segment'});
  push @qxtras, qq(chr_start <  '$opts->{'end'}')   if(defined $opts->{'start'} && defined $opts->{'end'});
  push @qxtras, qq(chr_end   >  '$opts->{'start'}') if(defined $opts->{'start'} && defined $opts->{'end'});

  my $extra   = "WHERE " . join(' AND ', @qxtras)       if(scalar @qxtras > 0);
  
  my $query   = qq(SELECT score           AS score,
		          type            AS type,
		          method          AS method,
                          read_name       AS read_name,
                          chr_start       AS start,
                          chr_end         AS end,
                          orient          AS ori,
                          clone_name      AS clone
                   FROM   $table
                   $extra
                   ORDER by chr_start);



  ###print STDERR "$query\n";
  my $ref = $self->transport->query($query);

  for my $row (@{$ref}) {

    ##print STDERR "@$row\n";
    my $start = $row->{'start'};
    my $end   = $row->{'end'};
    ($start, $end) = ($end, $start) if($start > $end);

    next if $row->{'clone'} eq 'NULL';
  
    #########
    # safety catch. throw stuff which looks like it's out of bounds
    next if($start > $opts->{'end'}); 

    my($id,);
    if($row->{'type'} eq 'paired_clone'){
	$id = $row->{'clone'};
    }else{
	$id = $row->{'read_name'};
    }

    push @features, {
                     'id'      => $id, 
                     'score'   => $row->{'score'},
		     'method'  => $row->{'method'},		     
                     'start'   => $start,
                     'end'     => $end,
		     'ori'     => '-1',
		     'link'    => [map{$_.$row->{'clone'}}map{ref($_)eq"ARRAY"?@{$_}:$_}($self->{'link'})], 
		     'linktxt' => [map{ref($_)eq"ARRAY"?@{$_}:$_}($self->{'linktxt'})],
		     'typecategory' => "pig_bes_seq",
		     
		 };
  }

  return @features;



}

1;
