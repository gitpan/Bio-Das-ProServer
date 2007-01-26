package Bio::Das::ProServer::SourceAdaptor::chori_243;

=head1 AUTHOR

Stefan Graef <graef@ebi.ac.uk>.

Builds DAS features from sheep BAC end sequences (CHORI-243) 
stored in ensembl database (jb16_sheep_human_clones and 
jb16_sheep_cow_clones on ia64g).

=cut

use warnings;
use strict;

use Data::Dumper;

use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init
{
    my ($self) = @_;

    $self->{'capabilities'} = {
        'features' => '1.0',
        'stylesheet' => '1.0'
        };

}

sub build_features
{
    my ( $self, $args ) = @_;
    
    my $segment = $args->{'segment'} || return ();
    my $start   = $args->{'start'}   || return ();
    my $end     = $args->{'end'}     || return ();
    
    # get data
    my $query = 
        "SELECT daf.*,  ma.value 
           FROM misc_attrib ma, misc_feature mf, seq_region sr, dna_align_feature daf 
          WHERE sr.seq_region_id=mf.seq_region_id 
            AND sr.name = \"$segment\" 
            AND (( mf.seq_region_start > $start AND mf.seq_region_start < $end ) OR 
                 ( mf.seq_region_end > $start AND mf.seq_region_end < $end ))
            AND attrib_type_id=18 
            AND mf.misc_feature_id=ma.misc_feature_id 
            AND mf.seq_region_id=daf.seq_region_id 
            AND mf.seq_region_start=daf.seq_region_start 
            AND mf.seq_region_end=daf.seq_region_end;";
    
    my $ref = $self->transport->query($query);
    
    my @features;
    
    foreach my $ft (@{$ref}) {

        # get info of other features in group for DAS links and notes
        my @traces = ();
        my %notes = ();
        foreach my $f (@{$ref}) {
            if ($f->{value} eq $ft->{value}) {
                push (@traces, $f->{hit_name});
                $notes{$f->{hit_name}} = 
                    [ $segment, $f->{seq_region_start}, $f->{seq_region_end},
                      $f->{hit_start}, $f->{hit_end}, 
                      $f->{hit_strand}, $f->{perc_ident} ];
            }
        }
        
        # build DAS link
        my %traces = 
            map {
                "http://trace.ensembl.org/perl/traceview?traceid=$_" 
                    => $_                
                } @traces;

        # build group notes
        my $grp_note = '';
        foreach (@traces) {
            $grp_note .= 
                sprintf(
                        "trace %s (%s:%d,%d): hit start: %d, " . 
                        "hit end: %d (%d), %.2f%% ident.; ",
                        $_, @{$notes{$_}}
                        );
        }
        
        # determine arrow style
        my $type;
        if ($ft->{hit_strand} == 1) {
            $type = 'fclone';
        } else {
            $type = 'rclone';
        }
        
        # build features
        push @features,
        {
            'id' => $ft->{value},
            'start' => $ft->{seq_region_start},
            'end'   => $ft->{seq_region_end},
            'ori'   => $ft->{seq_region_strand},
            'score' => $ft->{score},
            'note'  => sprintf(
                               "trace: %s, hit start: %d, hit end: %d (%d); " .
                               "%.2f%% ident.",
                               $ft->{hit_name}, $ft->{hit_start}, $ft->{hit_end}, 
                               $ft->{hit_strand}, $ft->{perc_ident}
                               ),
            'link'  => "http://trace.ensembl.org/perl/traceview?traceid=$ft->{hit_name}",
            'linktxt'  => $ft->{hit_name},
            'type'  => $type,
            'typecategory' => 'clones',
            'group' => $ft->{value},
            'groupnote' => $grp_note,
            'grouplink'  => \%traces,
        };
    }    
    
    return @features;
}

sub das_stylesheet
{
    my $self = shift;

    return <<EOT;
<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="default">
     <TYPE id="default">
        <GLYPH>
           <ANCHORED_ARROW>
              <BGCOLOR>black</BGCOLOR>
              <FGCOLOR>black</FGCOLOR>
              <BUMP>0</BUMP>
              <HEIGHT>4</HEIGHT>
              <FONT>sanserif</FONT>
           </ANCHORED_ARROW>
        </GLYPH>
     </TYPE>
  </CATEGORY>
  <CATEGORY id="clones">
     <TYPE id="fclone">
        <GLYPH>
           <FARROW>
              <BGCOLOR>tomato</BGCOLOR>
              <FGCOLOR>tomato</FGCOLOR>
              <BUMP>0</BUMP>
              <HEIGHT>4</HEIGHT>
              <FONT>sanserif</FONT>
           </FARROW>
        </GLYPH>
     </TYPE>
     <TYPE id="rclone">
        <GLYPH>
           <RARROW>
              <BGCOLOR>darkblue</BGCOLOR>
              <FGCOLOR>darkblue</FGCOLOR>
              <BUMP>0</BUMP>
              <HEIGHT>4</HEIGHT>
              <FONT>sanserif</FONT>
           </RARROW>
        </GLYPH>
     </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>
EOT
}

sub length { 1 };

1;

