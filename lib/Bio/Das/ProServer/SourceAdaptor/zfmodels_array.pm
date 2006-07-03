#########
# Author: is1
# Maintainer: is1
# Created: 2004-12-21
# Last Modified: 2006-06-13
# Builds oligo mapping DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::zfmodels_array;

=head1 AUTHOR

Ian Sealy <Ian.Sealy@sanger.ac.uk>.

Copyright (c) 2004 The Sanger Institute

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

    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qbounds       = "";
    $qbounds          = qq(AND seq_region_start <= '$end' AND seq_region_end >= '$start') if($start && $end);
    my $query         = qq(SELECT of.oligo_probe_id,
                                  op.name,
                                  oa.name AS description,
                                  mismatches,
                                  seq_region_start,
                                  seq_region_end,
                                  seq_region_strand
                           FROM   oligo_feature of,
                                  seq_region sr,
                                  oligo_probe op,
                                  oligo_array oa
                           WHERE  of.seq_region_id  = sr.seq_region_id
                           AND    of.oligo_probe_id = op.oligo_probe_id
                           AND    op.oligo_array_id = oa.oligo_array_id
						   AND    oa.type='OLIGO'
                           AND    sr.name=$qsegment $qbounds);
    my $ref           = $self->transport->query($query);
    my @features      = ();

    foreach my $row (@{$ref}) {
        my $mismatches = $row->{'mismatches'};
        if ($mismatches) {
            $mismatches = 'Mismatch';
        } else {
            $mismatches = 'Full match';
        }
        my $note        = '';
        my $query = qq(SELECT oligo_feature_id FROM oligo_feature WHERE oligo_probe_id=) . $row->{'oligo_probe_id'};
        my $ref2  = $self->transport->query($query);
        my $mapcount = scalar @$ref2;
        if ($mapcount == 1) {
            $note = 'Uniquely mapped. ';
        } else {
            $note = "Not uniquely mapped. $mapcount matches in total. ";
        }
        $note .= $row->{'description'};
        push @features, {
            'id'     => $row->{'name'},
            'type'   => $mismatches,
            'method' => 'exonerate or SSAHA2',
            'start'  => $row->{'seq_region_start'},
            'end'    => $row->{'seq_region_end'},
            'ori'    => $row->{'seq_region_strand'} == 1 ? '+' : '-',
            'note'   => $note,
            'link'   => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zfmodels/arraymap.pl?oligoname=" . $row->{'name'},
            'linktxt'=> "Further information...",
        };
    }
    return @features;
}

1;

