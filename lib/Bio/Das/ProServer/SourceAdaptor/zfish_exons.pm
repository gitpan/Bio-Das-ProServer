#########

# Author: is1

# Maintainer: is1

# Created: 2006-06-23

# Last Modified: 2006-07-13

# Builds DAS features from a database containing a mapping of Vega (or Ensembl) exons to an Ensembl (or Vega) assembly

#

package Bio::Das::ProServer::SourceAdaptor::zfish_exons;



=head1 AUTHOR



Ian Sealy <is1@sanger.ac.uk>



Copyright (c) 2006 The Sanger Institute



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

                                  $table.exon_stable_id, $table.display_label, $table.zfin_id

                           FROM   $table,

                                  seq_region sr

                           WHERE  $table.seq_region_id = sr.seq_region_id

                           AND    sr.name          = $qsegment

                                  $qbounds

                        );

 

    my $ref           = $self->transport->query($query);

    my @features      = ();



    foreach my $row (@{$ref}) {

        

        my @link    = ("${link}Danio_rerio/contigview?transcript=" . $row->{'transcript_stable_id'});

        my @linktxt = ($linktxt);

        if ($row->{'zfin_id'}) {

            push @link,    'http://zfin.org/cgi-bin/webdriver?MIval=aa-markerview.apg&OID=' . $row->{'zfin_id'};

            push @linktxt, 'ZFIN';

        }

        

        push @features, {

            'id'           => $row->{'exon_stable_id'},

            'label'        => $row->{'exon_stable_id'},

            'type'         => 'exon',

            'group'        => $row->{'transcript_stable_id'},

            'grouplabel'   => $row->{'display_label'} || $row->{'transcript_stable_id'},

            'grouptype'    => 'transcript',

            'start'        => $row->{'seq_region_start'},

            'end'          => $row->{'seq_region_end'},

            'ori'          => $row->{'seq_region_strand'},

            'note'         => $row->{'status'} . ' ' . $row->{'biotype'},

            'groupnote'    => $row->{'status'} . ' ' . $row->{'biotype'},

            'link'         => \@link,

            'linktxt'      => \@linktxt,

            'grouplink'    => $link[0],

            'grouplinktxt' => $linktxt[0],

        };            

    }

    return @features;

}



1;



