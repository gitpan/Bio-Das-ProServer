#########
# Author: te3
# Maintainer: te3
# Created: 2006-06-09
# Last Modified: 2006-06-09
# Builds morpholino mapping DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::zfmodels_morpholino;
 
=head1 AUTHOR
 
Tina Eyre <te3@sanger.ac.uk>.
 
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
        'features' => '1.0',
    };
}
 
sub build_features {
    my ($self, $opts) = @_;
    my $segment       = $opts->{'segment'};
    my $start         = $opts->{'start'};
    my $end           = $opts->{'end'};
    my $dsn           = $self->{'dsn'};
    my $method        = $self->config()->{'method'};
    my $logic_name    = $self->config()->{'logic_name'};
    my $link_url      = $self->config()->{'link_url'};
 
    my $qbounds       = qq(AND daf.seq_region_start <= '$end' AND daf.seq_region_end >= '$start') if($start && $end);
    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qlogic_name   = $self->transport->dbh->quote($logic_name);
 
    my $query         = qq(SELECT daf.hit_name, daf.seq_region_start, daf.seq_region_end, daf.seq_region_strand, daf.perc_ident, daf.score, m.zfin_id
                           FROM   dna_align_feature daf,
                                  seq_region sr,
                                  morpholino m,
                                  analysis a
                           WHERE  a.logic_name      = $qlogic_name
                           AND    daf.analysis_id   = a.analysis_id
                           AND    sr.name           = $qsegment
                           AND    daf.seq_region_id = sr.seq_region_id
                           AND    daf.hit_name      = m.morpholino_name
                                  $qbounds);
  
    my $ref           = $self->transport->query($query);
    my @features      = ();
 
    foreach my $row (@{$ref}) {
 
        my $note = 'Coverage: '.$row->{'score'}.'% Identity: '.$row->{'perc_ident'}.'%.';
 
        my $query = "SELECT daf.hit_name
                       FROM dna_align_feature daf, analysis a
                      WHERE daf.hit_name    = '".$row->{'hit_name'}."'
                        AND daf.analysis_id = a.analysis_id
                        AND a.logic_name    = $qlogic_name";
 
        my $ref2  = $self->transport->query($query);
        my $mapcount = scalar @$ref2;
        if ($mapcount == 1) {
            $note .= ' Uniquely mapped. ';
         
            push @features, {
                'id'          => $row->{'hit_name'},
                'method'      => $method,
                'start'       => $row->{'seq_region_start'},
                'end'         => $row->{'seq_region_end'},
                'ori'         => $row->{'seq_region_strand'},
                'note'        => $note,
                'link'        => $link_url.$row->{'zfin_id'},
                'linktxt'     => $row->{'zfin_id'},
            };
 
        } else {
            $note .= " Not uniquely mapped. $mapcount matches in total. ";
         
            push @features, {
                'id'          => $row->{'hit_name'},
                'method'      => $method,
                'start'       => $row->{'seq_region_start'},
                'end'         => $row->{'seq_region_end'},
                'ori'         => $row->{'seq_region_strand'},
                'note'        => $note,
                'link'        => 'http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/morph_map.pl?morph='.$row->{'hit_name'},
                'linktxt'     => 'See all '.$row->{'hit_name'}.' hits',
            };
        }
    }
    return @features;
}
 
1;
 
