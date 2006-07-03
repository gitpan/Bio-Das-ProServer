#########
# Author: te3
# Maintainer: te3
# Created: 2006-06-09
# Last Modified: 2006-06-09
# Builds EST mapping DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::zfmodels_est;

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

    my $qbounds       =  qq(AND daf.seq_region_start <= '$end' AND daf.seq_region_end >= '$start') if($start && $end);
    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qlogic_name   = $self->transport->dbh->quote($logic_name);

    my $query         = qq(SELECT daf.hit_name, daf.seq_region_start, daf.seq_region_end, daf.seq_region_strand, daf.perc_ident, daf.score
                           FROM   dna_align_feature daf,
                                  seq_region sr,
                                  analysis a
                           WHERE  a.logic_name      = $qlogic_name
                           AND    daf.analysis_id   = a.analysis_id
                           AND    daf.seq_region_id = sr.seq_region_id
                           AND    sr.name           = $qsegment
                                  $qbounds);
 
    my $ref           = $self->transport->query($query);
    my @features      = ();

    foreach my $row (@{$ref}) {

        my $hit_name = $row->{'hit_name'};
        $hit_name =~ s/EST:\d+:(.+):\d+:\d+:-?1/$1/; #convert from slice to sequence name

        my $note = 'Coverage: '.$row->{'score'}.' Identity: '.$row->{'perc_ident'};

        push @features, {
            'id'          => $hit_name,
            'method'      => $method,
            'start'       => $row->{'seq_region_start'},
            'end'         => $row->{'seq_region_end'},
            'ori'         => $row->{'seq_region_strand'},
            'note'        => $note,
        };            
        
    }
    return @features;
}

1;

