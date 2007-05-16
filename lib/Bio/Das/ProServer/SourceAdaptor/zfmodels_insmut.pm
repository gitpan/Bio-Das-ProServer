#########
# Author: is1
# Maintainer: is1
# Created: 2005-03-14
# Last Modified: 2006-06-12
# Builds ZF-MODELS insertional mutation DAS features from a database
#
package Bio::Das::ProServer::SourceAdaptor::zfmodels_insmut;

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
    my $logic_name    = $self->config()->{'logic_name'};
	
	my $qlogic_name   = $self->transport->dbh->quote($logic_name);
    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qbounds       = "";
    $qbounds          = qq(AND seq_region_start <= '$end' AND seq_region_end >= '$start') if($start && $end);
    my $query         = qq(SELECT daf.hit_name,
                                  daf.seq_region_start,
                                  daf.seq_region_end,
                                  daf.seq_region_strand,
								  daf.score
                           FROM   dna_align_feature daf,
                                  seq_region sr,
								  analysis a
                           WHERE  daf.seq_region_id = sr.seq_region_id
                           AND    daf.analysis_id = a.analysis_id
						   AND    a.logic_name = $qlogic_name
                           AND    sr.name=$qsegment $qbounds);
    my $ref           = $self->transport->query($query);
    my @features      = ();

    foreach my $row (@{$ref}) {
        my $note  = '<img width="160" height="120" src="http://clgy.no/clgyimages/icons/TN_CLGY' . $row->{'hit_name'} . '.JPG" /><br />';
        my $query = "SELECT hit_name FROM dna_align_feature WHERE hit_name='" . $row->{'hit_name'} . "'";
        my $ref2  = $self->transport->query($query);
        my $mapcount = scalar @$ref2;
        if ($mapcount == 1) {
            $note .= 'Uniquely mapped.';
        } else {
            $note .= "Not uniquely mapped. $mapcount matches in total.";
        }
        push @features, {
            'id'     => 'CLGY' . $row->{'hit_name'},
            'type'   => 'insertational mutagenesis line',
            'method' => 'Becker lab, SARS',
			'score'  => $row->{'score'},
            'start'  => $row->{'seq_region_start'},
            'end'    => $row->{'seq_region_end'},
            'ori'    => $row->{'seq_region_strand'} eq '1' ? '+' : '-',
            'note'   => $note,
            'link'   => "http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zfmodels/ins_mut_map.pl?cellline_id=CLGY" . $row->{'hit_name'},
            'linktxt'=> "Further information...",
        };
    }
    return @features;
}

1;

