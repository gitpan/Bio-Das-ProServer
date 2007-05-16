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
        SELECT   lp.project_id, lmu.mutation_id, lmu.amino_from,
                 lmu.amino_to, lmu.amino, lmu.`type`,
                 lp.description, lp.email, lma.seq_region_start,
                 lma.seq_region_end, lma.seq_region_strand
        FROM     limstill_projects lp,
                 limstill_mutations lmu,
                 limstill_mapping lma
        WHERE    lp.project_id       = lmu.project_id
        AND      lp.project_id       = lma.project_id
        AND      lmu.amplicon        = lma.amplicon
        AND      lma.assembly        = $assembly
        AND      lma.seq_region_name = '$seg'
        $qbounds
    );
    
    my @results;
    
    foreach ( @{$self->transport->query($query)} ) {
        my $url = 'http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/tilling/mutation.pl'
                  . '?project_id='  . $_->{'project_id'}
                  . '&mutation_id=' . $_->{'mutation_id'}
                  ;
        my $note = ucfirst($_->{'type'})
                   . ' mutation (' . $_->{'amino'} . '). '
                   . 'Contact: ' . $_->{'description'} . ' ' . $_->{'email'}
                   . '<br />'
                   . '<img src="http://www.sanger.ac.uk/cgi-bin/Projects/D_rerio/tilling/png.pl?mutation_id=' . $_->{'mutation_id'} . '" />'
                   ;
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
            'note'      => $note,
        };
    }
    
    return (@results);
}

1;
