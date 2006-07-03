#########
# Author: is1
# Maintainer: is1
# Created: 2006-03-08
# Last Modified: 2006-03-14
# Builds DAS features for TILLING mutations

package Bio::Das::ProServer::SourceAdaptor::zfmodels_tilling;

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

#######################################################################################################
sub init {
    my $self                = shift;
    $self->{'capabilities'} = { 'features' => '1.0', };
}

#######################################################################################################
sub length { 1; };

#######################################################################################################
sub build_features {
    my ($self, $opts) = @_;
    my $seg   = $opts->{'segment'};
    my $start = $opts->{'start'};
    my $end   = $opts->{'end'};
	
	my $assembly = $self->config()->{'assembly'};

    my $qbounds = "";
    $qbounds    = qq(AND seq_region_start <= '$end' AND seq_region_end >= '$start') if($start && $end);
    my $query = qq(
        SELECT   mu.experiment_id, t.trace_id, mu.amino_from, mu.amino_to, mu.amino,
                 mu.type, e.curator, ma.seq_region_start, ma.seq_region_end, ma.seq_region_strand
        FROM     experiment e, mutation mu, trace t, mapping ma
        WHERE    e.experiment_id    = mu.experiment_id
        AND      mu.experiment_id   = ma.experiment_id
        AND      mu.trace_id        = t.trace_id
		AND      ma.assembly        = $assembly
        AND      ma.seq_region_name = '$seg'
        $qbounds
    );
    
    my @results;
    
    foreach ( @{$self->transport->query($query)} ) {
        my $url = 'http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/zfmodels/tilling/tilling.pl'
                  . '?exp='   . $_->{'experiment_id'}
                  . '&trace=' . $_->{'trace_id'}
                  ;
        
#        my $type = $_->{'type'} . ' ' . $_->{'amino_from'} . '-' . $_->{'amino_to'};
        my $type = $_->{'type'} . ' (' . $_->{'amino'} . ')';
        
        push @results, {
            'id'        => $type,
            'start'     => $_->{'seq_region_start'},
            'end'       => $_->{'seq_region_end'},
            'ori'       => $_->{'seq_region_strand'} == 1 ? '+' : '-',
            'label'     => '',
            'type'      => $_->{'type'},
            'method'    => '',
            'link'      => $url,
            'linktxt'   => 'Further information...',
            'note'      => ucfirst($_->{'type'}) . ' mutation (' . $_->{'amino'} . '). ' .'Contact: ' . $_->{'curator'},
        };
    }
    
    return (@results);
}

1;
