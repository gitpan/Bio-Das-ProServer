package Bio::Das::ProServer::SourceAdaptor::jgi_dbi;

=head1 AUTHOR

Stefan Graef <graef@ebi.ac.uk>.

Builds DAS features for JGI gene models (transcripts and CDS) from simple 
database. It returns all features of a group represented in the requested 
region. Features outside the region are relocated as "hidden" one-basepair
features at the edge of the region (see stylesheet).

=cut

use warnings;
use strict;

use Data::Dumper;

use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init
{
    my ($self) = @_;

    $self->{'capabilities'} = {
        'features'   => '1.0',
        'stylesheet' => '1.0'
        };
}

sub build_features
{
    my ( $self, $args ) = @_;
    
    my $segment = $args->{'segment'} || return ();
    my $start   = $args->{'start'}   || return ();
    my $end     = $args->{'end'}     || return ();

    return() if ($segment !~ m/(^\d+[pq]$|^scaffold_\d+$)/); 
    
    ### get data
    
    my $qbounds = ($start && $end)?qq(AND start <= $end AND end >= $start):"";
    my $type = $self->config()->{'type'};

    ## all groups in region
    my $query = 
        "SELECT DISTINCT group_id
           FROM feature 
          WHERE segment=\'$segment\' $qbounds
            AND type_id = \'$type\'";
    
    my @groups = @{$self->transport->query($query)};
    @groups = map ($_->{'group_id'}, @groups);
    
    ## all features of group
    my $qgroups = " AND group_id IN ('" 
        . join("', '", @groups) . "') ";

    $query = 
        "SELECT *
           FROM feature 
          WHERE segment=\'$segment\' $qgroups
            AND type_id = \'$type\'
          ORDER BY start";

    my $features = $self->transport->query($query);

    my @features;
    
    ### build features
    foreach my $ft (@{$features}) {

        my $ftstart = $ft->{'start'};
        my $ftend = $ft->{'end'};
        my $type = $ft->{'type_id'};
        
        if ($ftend < $start){ 
            $ftend = $ftstart = $start; 
            $type .= ":hidden";
        }
        if ($ftstart > $end){
            $ftend = $ftstart = $end;
            $type .= ":hidden";
        }
        
        (my $linkid = $ft->{note} ) =~ s/.+Id //;
        my $link = $self->config()->{'link'} . $linkid;

        push @features,
        {
            'id'           => $ft->{feature_id},
            'start'        => $ftstart,
            'end'          => $ftend,
            'ori'          => $ft->{ori},
            'phase'        => $ft->{phase},
            'type'         => $type,
            'typecategory' => 'default',
            'method'       => $ft->{method},
            'group'        => $ft->{group_id},
            'grouptype'    => $type,
            'groupnote'    => $ft->{method},
            'grouplink'    => $link,
            'grouplinktxt' => $ft->{note},
        }
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
           <BOX>
              <FGCOLOR>darkblue</FGCOLOR>
              <BGCOLOR>blue</BGCOLOR>
           </BOX>
        </GLYPH>
     </TYPE>
     <TYPE id="CDS:hidden">
        <GLYPH>
           <LINE>
              <FGCOLOR>darkblue</FGCOLOR>
              <BGCOLOR>blue</BGCOLOR>
           </LINE>
        </GLYPH>
     </TYPE>
     <TYPE id="exon:hidden">
        <GLYPH>
           <LINE>
              <FGCOLOR>darkblue</FGCOLOR>
              <BGCOLOR>blue</BGCOLOR>
           </LINE>
        </GLYPH>
     </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>
EOT
}

sub length { 1 };

1;
