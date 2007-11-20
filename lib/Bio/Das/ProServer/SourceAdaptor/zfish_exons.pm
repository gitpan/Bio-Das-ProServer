#########

# Author: is1

# Maintainer: te3

# Created: 2006-06-23

# Last Modified: $Date: 2007/11/20 20:12:21 $

# Builds DAS features from a database containing a mapping of Vega (or Ensembl) exons to an Ensembl (or Vega) assembly.

# Uses a stylesheet to differentially colour exons mapped by different methods.

# Modified from Bio::Das::ProServer::SourceAdaptor::zfish_exons by is1

#

package Bio::Das::ProServer::SourceAdaptor::zfish_exons;



=head1 AUTHOR



Tina Eyre <te3@sanger.ac.uk>



Copyright (c) 2007 The Sanger Institute



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

        'features'   => '1.0',
	'stylesheet' => '1.0',
    };

}



sub build_features {

    my ($self, $opts) = @_;

    my $segment       = $opts->{'segment'};

    my $start         = $opts->{'start'};

    my $end           = $opts->{'end'};

    my $dsn           = $self->{'dsn'};

    

    my $table         = $self->config->{'table'};

    my $link          = $self->config->{'link'};

    my $linktxt       = $self->config->{'linktxt'};

    my $qbounds       =  "AND $table.seq_region_start <= $end AND $table.seq_region_end >= $start" if $start && $end;

    my $qsegment      = $self->transport->dbh->quote($segment);



    my $query         = qq(SELECT $table.seq_region_start, $table.seq_region_end, $table.seq_region_strand,

                                  $table.biotype, $table.status, $table.transcript_stable_id,

                                  $table.exon_stable_id, $table.display_label, $table.zfin_id, $table.method

                           FROM   $table,

                                  seq_region sr

                           WHERE  $table.seq_region_id = sr.seq_region_id

                           AND    sr.name          = $qsegment

                                  $qbounds

                        );

 

    my $ref           = $self->transport->query($query);

    my @features      = ();


    #find out which methods used for the exons of this transcript
    my %methods;
    foreach my $row (@{$ref}) {
        my $method = $row->{'method'};
	$methods{$row->{'transcript_stable_id'}}{$method} = 1;
    }

    foreach my $row (@{$ref}) {

        

        my @link    = ("${link}Danio_rerio/contigview?transcript=" . $row->{'transcript_stable_id'});

        my @linktxt = ($linktxt);

        if ($row->{'zfin_id'}) {

            push @link,    'http://zfin.org/cgi-bin/webdriver?MIval=aa-markerview.apg&OID=' . $row->{'zfin_id'};

            push @linktxt, 'ZFIN';

        }

	#note about the method used to transfer all exons of this transcript
	my $group_method_note = "This transcript was transferred directly from the corresponding clone in $linktxt.";
	if (exists $methods{$row->{'transcript_stable_id'}}{'Exonerate'} and exists $methods{$row->{'transcript_stable_id'}}{'Clone transfer'}) {
	    $group_method_note = "This exons of this transcript were projected by both direct transfer from the corresponding $linktxt clone (dark blue) and Exonerate mapping (light blue).";
	}
	elsif (exists $methods{$row->{'transcript_stable_id'}}{'Exonerate'}) {
	    $group_method_note = "This $linktxt transcript was projected to this location based on Exonerate mapping.";
	}

        my $method = $row->{'method'};
	my $type = 'exon'; #used for colour-coding of the exon by the style sheet
        my $group_type = 'transcript:transfer';
	if ($method eq 'Exonerate') {
	    $type = 'intron';
            $group_type = 'transcript:exonerate';
	}

        push @features, {

            'id'           => $row->{'exon_stable_id'},

            'label'        => $row->{'exon_stable_id'},

            'type'         => $type,
	    
	    'method'       => $method,

            'group'        => $row->{'transcript_stable_id'},

	    'grouplabel'   => $row->{'transcript_stable_id'},

            'grouplabel'   => $row->{'display_label'} || $row->{'transcript_stable_id'},

            'grouptype'    => $group_type, 

            'start'        => $row->{'seq_region_start'},

            'end'          => $row->{'seq_region_end'},

            'ori'          => $row->{'seq_region_strand'},

            'note'         => $row->{'status'} . ' ' . $row->{'biotype'},

            'groupnote'    => $row->{'status'} . ' ' . $row->{'biotype'} . ". $group_method_note",

            'link'         => \@link,

            'linktxt'      => \@linktxt,

            'grouplink'    => $link[0],

            'grouplinktxt' => $linktxt[0],

        };            

    }

    return @features;

}

sub das_stylesheet{
  my ($self) = @_;

  my $response = qq(<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
		    <DASSTYLE>
		    <STYLESHEET version="0.1">
                     <CATEGORY id="group">
                      <TYPE id="transcript:exonerate">
                       <GLYPH>
                        <LINE>
                         <POINT>1</POINT>
                         <HEIGHT>10</HEIGHT>
                         <FGCOLOR>darkturquoise</FGCOLOR>
                         <STYLE>intron</STYLE>
                        </LINE>
                       </GLYPH>
                      </TYPE> 
                      <TYPE id="transcript:transfer">
                       <GLYPH>
                        <LINE>
                         <POINT>1</POINT>
                         <HEIGHT>10</HEIGHT>
                         <FGCOLOR>blue</FGCOLOR>
                         <STYLE>intron</STYLE>
                        </LINE>
                       </GLYPH>
                      </TYPE> 
                     </CATEGORY>
  
		    <CATEGORY id="default">
		      <TYPE id="exon">
		       <GLYPH>
		        <BOX>
		         <BGCOLOR>blue</BGCOLOR>
		        </BOX>
		      </GLYPH>
		     </TYPE>

		     <TYPE id="intron">
		      <GLYPH>
		       <BOX>
		        <BGCOLOR>darkturquoise</BGCOLOR>
		       </BOX>
		      </GLYPH>
		     </TYPE>

	           </CATEGORY>
		   </STYLESHEET>
		   </DASSTYLE>\n);

  return $response;
}


1;



