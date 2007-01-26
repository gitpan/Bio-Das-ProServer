package Bio::Das::ProServer::SourceAdaptor::CNVDB;

=head1 AUTHORS

Eugene Kulesha <ek@ebi.ac.uk>
Dan Andrews <dta@sanger.ac.uk>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
use Data::Dumper;

@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
    my $self = shift;
    $self->{'capabilities'} = {'features'   => '1.0',
			       'types'      => '1.0',
			       'stylesheet' => '1.0'};
}

sub build_features {
    my ($self, $opts) = @_;
    my $segment       = $opts->{'segment'};
    my $start         = $opts->{'start'};
    my $end           = $opts->{'end'};
    my $dsn           = $self->{'dsn'};
    my $dbtable       = $dsn;

    #########
    # if this is a hydra-based source the table name contains the hydra name and needs to be switched out
    #
    my $hydraname     = $self->config->{'hydraname'};
    if($hydraname) {
	my $basename = $self->config->{'basename'};
	$dbtable =~ s/$hydraname/$basename/;
    }

    my $qsegment      = $self->transport->dbh->quote($segment);
    my $qbounds       = "";
    $qbounds          = qq(AND start <= '$end' AND end >= '$start') if($start && $end);
    my $query         = qq(SELECT id, type, method, chr, start, end, 1 as strand, score, note, link
			   FROM $dbtable 
			   WHERE chr = $qsegment 
			   $qbounds);
    my $ref           = $self->transport->query($query);
    my @features      = ();


    for my $row (@{$ref}) {
	my ($start, $end, $strand) = ($row->{'start'}, 
				      $row->{'end'}, 
				      $row->{'strand'});

	if($start > $end) {
	    ($start, $end) = ($end, $start);
	}

	my $f = {
	    'id'     => $row->{'id'},
	    'type'   => $row->{'type'} || $dbtable,
	    'method' => $row->{'method'} || $dbtable,
	    'start'  => $start,
	    'end'    => $end,
	    'ori'    => $strand,
	    'score'  => $row->{'score'},
	    'note'   => [$row->{'note'}],
	    'link'   => $row->{'link'},
	};

	push @features, $f;
    }

    return @features;
}

sub build_types {
    my ( $self, $args ) = @_;
    
    my $segment       = $args->{'segment'};
    my $segment_start = $args->{'start'};
    my $segment_end   = $args->{'end'};
    
    my $dsn           = $self->{'dsn'};
    my $dbtable       = $dsn;

    my $transport = $self->transport();
    my $dbh       = $transport->dbh();

    my $bounds_part  = '';
    my $segment_part = '';

    if ( defined $segment ) {
	my $quoted_segment = $dbh->quote($segment);

	$segment_part = "WHERE chr = $quoted_segment";
	
	if ( defined($segment_start) && defined($segment_end) ) {
	    my $quoted_segment_start = $dbh->quote($segment_start);
	    my $quoted_segment_end   = $dbh->quote($segment_end);
	    
	    $bounds_part = qq(
			      AND ((start >= $quoted_segment_start
			      AND start <= $quoted_segment_end)
			      OR (end >= $quoted_segment_start
			      AND end <= $quoted_segment_end))
			      );
         }
     }

     my $query = qq( SELECT COUNT(*) AS 'count', type, method
                     FROM $dbtable $segment_part $bounds_part
                     GROUP BY type, method );

     my $rows = $transport->query($query);
     my @types = ();

     foreach my $row ( @{$rows} ) {
         push @types, { 'type'   => $row->{'type'},
                        'method' => $row->{'method'},
                        'count'  => $row->{'count'} };
     }

     return @types;
}

sub das_stylesheet {
     my $self = shift;
     my $dsn           = $self->{'dsn'};
     my $dbtable       = $dsn;

     return <<EOT;
     <?xml version="1.0" standalone="yes"?>
	 <!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
	 <DASSTYLE>
	 <STYLESHEET version="1.0">
	 <CATEGORY id="default">
	 <TYPE id="default">
         <GLYPH>
	 <BOX>
	 <BGCOLOR>black</BGCOLOR>
	 <FGCOLOR>black</FGCOLOR>
	 <BUMP>0</BUMP>
	 <HEIGHT>4</HEIGHT>
	 <FONT>sanserif</FONT>
	 </BOX>
         </GLYPH>
	 </TYPE>
	 </CATEGORY>
	 </STYLESHEET>
	 </DASSTYLE>
EOT
}

1;
