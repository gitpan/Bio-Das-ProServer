#########
# Author: avc
# Maintainer: avc
# Created: 2004-02-16
# Last Modified: 2004-07-16
# Builds DAS features from tilepath database

package Bio::Das::ProServer::SourceAdaptor::tilepath;

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

Copyright (c) 2004 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

#######################################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

#######################################################################################################
sub length { 1;};

#######################################################################################################
sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};

  return if(CORE::length("$seg") > 2);

  #mysql> describe 6_tiles;
  #+-----------------------+--------------+------+-----+---------+-------+
  #| Field                 | Type         | Null | Key | Default | Extra |
  #+-----------------------+--------------+------+-----+---------+-------+
  #| tile_index            | int(11)      |      |     | 0       |       |
  #| effective_insert_size | int(11)      |      |     | 0       |       |
  #| total_insert_size     | int(11)      |      |     | 0       |       |
  #| overlap               | int(11)      |      |     | 0       |       |
  #| start                 | int(11)      |      |     | 0       |       |
  #| end                   | int(11)      |      |     | 0       |       |
  #| read_id               | varchar(100) |      |     |         |       |
  #| template_id           | varchar(100) |      |     |         |       |
  #| score                 | int(11)      |      |     | 0       |       |
  #+-----------------------+--------------+------+-----+---------+-------+
  #9 rows in set (0.00 sec)
  #mysql> describe 6_tile_path;
  #+-------------+--------------+------+-----+---------+-------+
  #| Field       | Type         | Null | Key | Default | Extra |
  #+-------------+--------------+------+-----+---------+-------+
  #| tile_index  | int(11)      |      |     | 0       |       |
  #| insert_size | int(11)      |      |     | 0       |       |
  #| overlap     | int(11)      |      |     | 0       |       |
  #| score       | int(11)      |      |     | 0       |       |
  #| start       | int(11)      |      |     | 0       |       |
  #| end         | int(11)      |      |     | 0       |       |
  #| id          | varchar(100) |      |     |         |       |
  #+-------------+--------------+------+-----+---------+-------+

  my $path_table_name = $seg . "_tile_path";
  my $tiles_table_name = $seg . "_tiles";

  my $qbounds = ($start && $end) ? qq(WHERE ${path_table_name}.start <= $end AND ${path_table_name}.end >= $start):"";
  
  my $query   = qq(SELECT ${path_table_name}.id			    AS read_id,
                          ${path_table_name}.start			AS start,
                          ${path_table_name}.end			AS end,
                          ${path_table_name}.score			AS score,
                          ${tiles_table_name}.template_id	AS template_id
		   		   FROM   $path_table_name, $tiles_table_name
		           $qbounds
				   AND
				   	${path_table_name}.id = ${tiles_table_name}.read_id
                   ORDER BY start
				   );

  my @results;
  
  foreach ( @{$self->transport->query($query)} ) {
  	
	my $link = $self->config->{'link1'};
	$link =~ s/\#\#\#\#/$_->{'read_id'}/;		
	my $method = "ssaha2";
	$method = $method . ":" . "tilepath";
			
  	push @results, 
    				{
    				  'id'      => $_->{'template_id'},
    				  'type'    => sprintf("%s", "tilepath:read"),
			      'typecategory'=> "similarity",
    				  'method'  => $method,
    				  'start'   => $_->{'start'},
    				  'end'     => $_->{'end'},
    				  'ori'     => "-",
    				  'score'   => $_->{'score'},
    				  'link'    => $link,
    				  'linktxt' => "Forward read data...",
    				};

  }
  
  return (@results);

}

#######################################################################################################
sub das_stylesheet{
  my ($self) = @_;

my $response = qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="similarity">
     <TYPE id="tilepath:read">
        <GLYPH>
           <FARROW>
              <BGCOLOR>gold4</BGCOLOR>
              <FGCOLOR>gold4</FGCOLOR>
              <BUMP>0</BUMP>
              <FONT>sanserif</FONT>
           </FARROW>
        </GLYPH>
     </TYPE>
  </CATEGORY>
  <CATEGORY id="default">
     <TYPE id="default">
        <GLYPH>
           <BOX>
              <BGCOLOR>red</BGCOLOR>
              <FGCOLOR>blue</FGCOLOR>
              <BUMP>0</BUMP>
              <FONT>sanserif</FONT>
           </BOX>
        </GLYPH>
     </TYPE>
  </CATEGORY>
  <CATEGORY id="structural">
     <TYPE id="Component:chromosome">
        <GLYPH>
           <BOX>
              <BGCOLOR>purple</BGCOLOR>
              <FGCOLOR>yellow</FGCOLOR>
           </BOX>
        </GLYPH>
        <GLYPH zoom="low">
           <BOX>
              <BGCOLOR>yellow</BGCOLOR>
              <FGCOLOR>red</FGCOLOR>
           </BOX>
        </GLYPH>
     </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>\n);

  return $response;
}


1;
