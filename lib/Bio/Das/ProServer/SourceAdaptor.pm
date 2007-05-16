#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: $Date: 2007/05/11 23:21:29 $ $Author: rmp $
# Id:            $Id: SourceAdaptor.pm,v 2.59 2007/05/11 23:21:29 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor.pm,v $
# $HeadURL$
#
# Generic SourceAdaptor. Generates XML and manages callouts for DAS functions
#
package Bio::Das::ProServer::SourceAdaptor;
use strict;
use warnings;
use HTML::Entities;
use English qw(-no_match_vars);
use Carp;

our $VERSION  = do { my @r = (q$Revision: 2.59 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };
our $XSLFLUFF = q(<style type="text/css">html,body{background:#ffc;font-family:helvetica,arial,sans-serif;font-size:0.8em}thead{background:#700;color:#fff}thead th{margin:0;padding:2px}a{color:#a00}a:hover{color:#aaa}.tr1{background:#ffd}.tr2{background:#ffb}tr{vertical-align:top}</style>
<script type="text/javascript"><![CDATA[
addEvent(window,"load",zi);
function zi(){if(!document.getElementsByTagName)return;var ts=document.getElementsByTagName("table");for(var i=0;i!=ts.length;i++){t=ts[i];if(t){if(((' '+t.className+' ').indexOf("z")!=-1))z(t);}}}
function z(t){var tr=1;for(var i=0;i!=t.rows.length;i++){var r=t.rows[i];var p=r.parentNode.tagName.toLowerCase();if(p!='thead'){if(p!='tfoot'){r.className='tr'+tr;tr=1+!(tr-1);}}}}
function addEvent(e,t,f,c){/*Scott Andrew*/if(e.addEventListener){e.addEventListener(t,f,c);return true;}else if(e.attachEvent){var r=e.attachEvent("on"+t,f);return r;}}
function hideColumn(c){var t=document.getElementById('data');var trs=t.getElementsByTagName('tr');for(var i=0;i!=trs.length;i++){var tds=trs[i].getElementsByTagName('td');if(tds.length!=0)tds[c].style.display="none";var ths=trs[i].getElementsByTagName('th');if(ths.length!=0)ths[c].style.display="none";}}
]]></script>);

our $XSL      = {
		 'dsn.xsl' => q(<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" indent="yes"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head><title>ProServer: DSN List</title></head>
      <body>
        <div id="header"><h4>ProServer: DSN List</h4></div>
        <div id="mainbody">
          <table class="z" id="data">
            <thead><tr><th>Source</th><th>Version</th><th>Mapmaster</th><th>Description</th></tr></thead><tbody>
            <xsl:for-each select="/DASDSN/DSN">
              <xsl:sort select="@id"/>
                <tr>
                  <td><a><xsl:attribute name="href"><xsl:value-of select="SOURCE"/></xsl:attribute><xsl:value-of select="SOURCE"/></a></td>
                  <td><xsl:value-of select="SOURCE/@version"/></td>
                  <td><a><xsl:attribute name="href"><xsl:value-of select="MAPMASTER"/></xsl:attribute><xsl:value-of select="MAPMASTER"/></a></td>
                  <td><xsl:value-of select="DESCRIPTION"/></td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>),
		 'features.xsl' => q(<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" indent="yes"/>
  <xsl:template match="/">
    <html xmlns="http://www.w3.org/1999/xhtml">
      <head><title>ProServer: Features for <xsl:value-of select="/DASGFF/GFF/@href"/></title></head>
      <body>
        <div id="header"><h4>ProServer: Features for <xsl:value-of select="/DASGFF/GFF/@href"/></h4></div>
        <div id="mainbody">
          <table class="z" id="data">
            <thead><tr>
              <th onclick="hideColumn(0);">Label</th>
              <th onclick="hideColumn(1);">Segment</th>
              <th onclick="hideColumn(2);">Start</th>
              <th onclick="hideColumn(3);">End</th>
              <th onclick="hideColumn(4);">Orientation</th>
              <th onclick="hideColumn(5);">Notes</th>
              <th onclick="hideColumn(6);">Type</th>
              <th onclick="hideColumn(7);">Link</th>
            </tr></thead><tbody>
            <xsl:apply-templates select="/DASGFF/GFF/SEGMENT"/>
            </tbody>
          </table>
        </div>
      </body>
    </html>
  </xsl:template>
  <xsl:template match="SEGMENT">
    <xsl:for-each select="FEATURE">
      <xsl:sort select="@id"/>
      <tr>
        <td><xsl:value-of select="@id"/></td>
        <td><xsl:value-of select="../@id"/></td>
        <td><xsl:value-of select="START"/></td>
        <td><xsl:value-of select="END"/></td>
        <td><xsl:value-of select="ORIENTATION"/></td>
        <td><xsl:value-of select="TYPE"/></td>
        <td><xsl:value-of select="NOTE"/></td>
        <td><xsl:if test="LINK"><xsl:apply-templates select="LINK"/></xsl:if></td>
      </tr>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="LINK">
    [<a><xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute><xsl:value-of select="."/></a>]
  </xsl:template>
</xsl:stylesheet>),
		};

sub new {
  my ($class, $defs) = @_;
  my $self = {
	      'dsn'          => $defs->{'dsn'},
	      'port'         => $defs->{'port'},
	      'hostname'     => $defs->{'hostname'},
	      'baseuri'      => $defs->{'baseuri'},
	      'protocol'     => $defs->{'protocol'},
	      'config'       => $defs->{'config'},
	      'debug'        => $defs->{'debug'}    || undef,
	      '_data'        => {},
	      '_sequence'    => {},
	      '_features'    => {},
	      'capabilities' => {
				 'dsn' => '1.0',
				},
	     };

  bless $self, $class;
  $self->init($defs);

  if(!exists($self->{'capabilities'}->{'stylesheet'}) &&
     ($self->{'config'}->{'stylesheet'} ||
      $self->{'config'}->{'stylesheetfile'})) {
    $self->{'capabilities'}->{'stylesheet'} = '1.0';
  }
  return $self;
}

sub init {};

sub length { return 0; } ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub mapmaster {}

sub description {}

sub known_segments {}

sub segment_version {}

sub init_segments {}

sub dsn {
  my $self = shift;
  return $self->{'dsn'} || 'unknown';
};

sub dsnversion {
  my $self = shift;
  return $self->{'dsnversion'} || '1.0';
};

sub start { return 1; }

sub end {
  my $self = shift;
  return $self->length(@_);
}

sub transport {
  my $self = shift;

  if(!exists $self->{'_transport'}) {
    my $transport = 'Bio::Das::ProServer::SourceAdaptor::Transport::'.$self->config->{'transport'};

    eval "require $transport"; ## no critic(TestingAndDebugging::ProhibitNoStrict BuiltinFunctions::ProhibitStringyEval)

    eval {
      $self->{'_transport'} = $transport->new({
					       'dsn'    => $self->{'dsn'}, # for debug purposes
					       'config' => $self->config(),
					      });
    };
    $EVAL_ERROR and carp $EVAL_ERROR;
  }
  return $self->{'_transport'};
}

sub config {
  my ($self, $config) = @_;
  if(defined $config) {
    $self->{'config'} = $config;
  }
  return $self->{'config'};
}

sub implements {
  my ($self, $method) = @_;
  return $method?(exists $self->{'capabilities'}->{$method}):undef;
}

sub das_capabilities {
  my $self = shift;
  return join q(; ), map {
    "$_/$self->{'capabilities'}->{$_}"
  } grep {
    defined $self->{'capabilities'}->{$_}
  } keys %{$self->{'capabilities'}};
}

sub das_dsn {
  my $self    = shift;
  my $port    = $self->{'port'}?":$self->{'port'}":q();
  my $host    = $self->{'hostname'}||q();
  my $content = $self->open_dasdsn();

  for my $adaptor ($self->config->adaptors()) {
    my $dsn         = $adaptor->dsn();
    my $dsnversion  = $adaptor->dsnversion();
    my $mapmaster   = $adaptor->mapmaster()   || $adaptor->config->{'mapmaster'}   || "http://$host$port/das/$dsn/";
    my $description = $adaptor->description() || $adaptor->config->{'description'} || $dsn;
    $content       .= qq(  <DSN>
    <SOURCE id="$dsn" version="$dsnversion">$dsn</SOURCE>
    <MAPMASTER>$mapmaster</MAPMASTER>
    <DESCRIPTION>$description</DESCRIPTION>
  </DSN>\n);
  }

  $content .= $self->close_dasdsn();

  return ($content);
}

sub open_dasdsn {
  return qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASDSN SYSTEM 'http://www.biodas.org/dtd/dasdsn.dtd' >
<DASDSN>\n);
}

sub close_dasdsn {
  return qq(</DASDSN>\n);
}

sub unknown_segment {
  my ($self, $seg) = @_;
  return qq(    <UNKNOWNSEGMENT id="$seg" />\n);
}

#########
# code refactoring function to generate the link parts of the DAS response
#
sub _gen_link_das_response {
  my ($self, $link, $linktxt, $spacing) = @_;
  my $response = q();

  #########
  # if $link is a reference to and array or hash use their contents as multiple links
  #
  if(ref $link eq 'ARRAY') {
    while(my $k = shift @{$link}) {
      my $v;
      if(ref $linktxt eq 'ARRAY') {
	$v = shift @{$linktxt};
      }

      $v       ||= $linktxt;
      $response .= qq($spacing<LINK href="$k">$v</LINK>\n);
    }

  } elsif(ref $link eq 'HASH') {
    for my $k (sort { $link->{$a} cmp $link->{$b} } keys %{$link}) {
      $response .= qq($spacing<LINK href="$k">$link->{$k}</LINK>\n);
    }

  } elsif($link) {
    $response .= qq($spacing<LINK href="$link">$linktxt</LINK>\n);
  }
  return $response;
}

#########
# Recursive application of entity escaping
#
sub _encode {
  my ($self, $datum) = @_;
  if(!ref $datum) {
    return;
  }

  if(ref $datum eq 'HASH') {
    while(my ($k, $v) = each %{$datum}) {
      my $ek = encode_entities(decode_entities($k));

      if($ek ne $k) {
	delete $datum->{$k};
	$k = $ek;
	$datum->{$ek} = $v;
      }

      if(ref $v) {
	$self->_encode($v);
      } else {
	$datum->{$k} = encode_entities($v);
      }
    }

  } elsif(ref($datum) eq 'ARRAY') {
    @{$datum} = map { ref($_)?$self->_encode($_):encode_entities($_); } @{$datum};

  } elsif(ref($datum) eq 'SCALAR') {
    ${$datum} = encode_entities(${$datum});
  }
  return $datum;
}

#########
# code refactoring function to generate the feature parts of the DAS response
#
sub _gen_feature_das_response {
  my ($self, $feature, $spacing) = @_;
  $self->_encode($feature);

  my $response  = q();
  my $start     = $feature->{'start'}        || '0';
  my $end       = $feature->{'end'}          || '0';
  my $note      = $feature->{'note'}         || q();
  my $id        = $feature->{'id'}           || $feature->{'feature_id'}    || q();
  my $label     = $feature->{'label'}        || $feature->{'feature_label'} || $id;
  my $type      = $feature->{'type'}         || q();
  my $typetxt   = $feature->{'typetxt'}      || $type;
  my $method    = $feature->{'method'}       || q();
  my $method_l  = $feature->{'method_label'} || $method;
  my $group     = $feature->{'group_id'}     || $feature->{'group'}         || q();
  my $glabel    = $feature->{'grouplabel'}   || q();
  my $gtype     = $feature->{'grouptype'}    || q();
  my $gnote     = $feature->{'groupnote'}    || q();
  my $glink     = $feature->{'grouplink'}    || q();
  my $glinktxt  = $feature->{'grouplinktxt'} || q();
  my $score     = $feature->{'score'}        || q();
  my $ori       = $feature->{'ori'}          || '0';
  my $phase     = $feature->{'phase'}        || q();
  my $link      = $feature->{'link'}         || q();
  my $linktxt   = $feature->{'linktxt'}      || $link;
  my $target    = $feature->{'target'};
  my $cat       = (defined $feature->{'typecategory'})?qq(category="$feature->{'typecategory'}"):(defined $feature->{'type_category'})?qq(category="$feature->{'type_category'}"):q();
  my $subparts  = $feature->{'typesubparts'}    || 'no';
  my $supparts  = $feature->{'typessuperparts'} || 'no';
  my $ref       = $feature->{'typesreference'}  || 'no';
  $response    .= qq($spacing<FEATURE id="$id" label="$label">\n);
  $response    .= qq($spacing  <TYPE id="$type" $cat reference="$ref" subparts="$subparts" superparts="$supparts">$typetxt</TYPE>\n);
  $response    .= qq($spacing  <START>$start</START>\n);
  $response    .= qq($spacing  <END>$end</END>\n);
  $method and $response .= qq($spacing  <METHOD id="$method">$method_l</METHOD>\n);
  $score  and $response .= qq($spacing  <SCORE>$score</SCORE>\n);
  $phase  and $response .= qq($spacing  <PHASE>$phase</PHASE>\n);
  (defined $ori) and $response .= qq($spacing  <ORIENTATION>$ori</ORIENTATION>\n);

  #########
  # Allow the 'note' tag to point to an array of notes.
  #
  if(ref $note eq 'ARRAY' ) {
    for my $n (@{$note}) {
      next if(!$n);
      $response .= qq($spacing  <NOTE>$n</NOTE>\n);
    }

  } else {
    if($note) {
      $response .= qq($spacing  <NOTE>$note</NOTE>\n)
    }
  }

  #########
  # Target can be an array of hashes
  #
  if($target && (ref $target eq 'ARRAY')) {
    for my $t (@{$target}) {
      $response .= sprintf qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
			   $t->{'id'}    ?qq( id="$t->{'id'}")       :q(),
			   $t->{'start'} ?qq( start="$t->{'start'}") :q(),
			   $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :q(),
			   $t->{'targettxt'} || $t->{'target'} || sprintf q(%s:%d,%d), $t->{'id'}, $t->{'start'}, $t->{'stop'};
    }

  } elsif($feature->{'target_id'}) {
    $response .= sprintf qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
			 $feature->{'target_id'}    ?qq( id="$feature->{'target_id'}")       :q(),
			 $feature->{'target_start'} ?qq( start="$feature->{'target_start'}") :q(),
			 $feature->{'target_stop'}  ?qq( stop="$feature->{'target_stop'}")   :q(),
			 $feature->{'targettxt'} || $feature->{'target_id'} || $feature->{'target'} ||
			 sprintf q(%s:%d,%d), $feature->{'target_id'}, $feature->{'target_start'}, $feature->{'target_stop'};
  }

  $response .= $self->_gen_link_das_response($link, $linktxt, "$spacing  ");

  #####
  # if $group is a ref to an array then use group_id of the hashs in that array as the key in a new hash
  #
  if (ref $group eq 'ARRAY') {
    my $groups = {};
    for my $g (@{$group}) {
      $groups->{$g->{'group_id'}} = $g;
    }
    $group = $groups;
  }

  #########
  # if $group is a hash reference treat its keys as the multiple groups to be reported for this feature
  #
  my $groups = {(ref $group eq 'HASH')?%{$group}:($group => {
							     'grouplabel'   => $glabel,
							     'grouptype'    => $gtype,
							     'groupnote'    => $gnote,
							     'grouplink'    => $glink,
							     'grouplinktxt' => $glinktxt,
							    })};

  for my $groupi (grep { (substr $_, 0, 1) ne '_' } keys %{$groups}) {
    if($groupi) {
      my $groupinfo = $groups->{$groupi};
      my $gnotei    = $groupinfo->{'groupnote'}   || q();
      my $glinki    = $groupinfo->{'grouplink'}   || q();
      my $gtargeti  = $groupinfo->{'grouptarget'} || q();
      $response    .= sprintf qq($spacing  <GROUP id="%s"%s%s),
			      $groupi,
			      $groupinfo->{'grouplabel'} ?qq( label="$groupinfo->{'grouplabel'}") :q(),
			      $groupinfo->{'grouptype'}  ?qq( type="$groupinfo->{'grouptype'}")   :q();

      if (!$gnotei && !$glinki) {
        $response .= qq(/>\n);

      } else {
        my $glinktxti = $groupinfo->{'grouplinktxt'} || $glinki;
        $response    .= qq(>\n);

	# Allow the 'note' tag to point to an array of notes.
	if(ref $gnotei eq 'ARRAY') {
	  for my $n (@{$gnotei}) {
	    $n or next;
	    $response .= qq($spacing  <NOTE>$n</NOTE>\n);
	  }

	} elsif($gnotei) {
	  $response .= qq($spacing  <NOTE>$gnotei</NOTE>\n);
	}
        $response .= $self->_gen_link_das_response($glinki, $glinktxti, "$spacing  ");

	if(ref $gtargeti eq 'ARRAY') {
	  for my $t (@{$gtargeti}) {
	    $response .= sprintf qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
				 $t->{'id'}    ?qq( id="$t->{'id'}")       :q(),
				 $t->{'start'} ?qq( start="$t->{'start'}") :q(),
				 $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :q(),
				 $t->{'targettxt'} || $t->{'target'} || sprintf '%s:%d,%d', $t->{'id'}, $t->{'start'}, $t->{'stop'};
	  }
	}

        $response .= qq($spacing  </GROUP>\n);
      }
    }
  }

  $response .= qq($spacing</FEATURE>\n);
  return $response;
}

sub das_features {
  my ($self, $opts) = @_;
  my $response      = q();

  $self->init_segments($opts->{'segments'});

  #########
  # features on segments
  #
  for my $seg (@{$opts->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();
    my $segstart       = $start || $self->start($seg) || q();
    my $segend         = $end   || $self->end($seg)   || q();

    if ( $self->known_segments() ) {
      if(!grep { /$seg/mx } $self->known_segments()) {
	$response .= $self->unknown_segment($seg);
	next;
      }
    }

    my $segment_version = $self->segment_version($seg) || q(1.0);
    $response          .= qq(    <SEGMENT id="$seg" version="$segment_version" start="$segstart" stop="$segend">\n);

    for my $feature ($self->build_features({
					    'segment' => $seg,
					    'start'   => $start,
					    'end'     => $end,
					   })) {
      $response .= $self->_gen_feature_das_response($feature, q(    ));
    }
    $response .= qq(    </SEGMENT>\n);
  }

  #########
  # features by specific id
  #
  my $error_feature = 1;

  for my $fid (@{$opts->{'features'}}) {

    my @f = $self->build_features({
				   'feature_id' => $fid,
				  });
    if (!scalar @f) {
      $response .= $self->error_feature($fid);
      next;
    }

    for my $feature (@f) {
      my $seg      = $feature->{'segment'}         || q();
      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || q();
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}   || q();
      my $segver   = $feature->{'segment_version'} || q(1.0);
      $response   .= qq(    <SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">\n);
      $response   .= $self->_gen_feature_das_response($feature, q(    ));
      $response   .= qq(    </SEGMENT>\n);
    }
  }

  #########
  # features by group id
  # Responses across multiple group_ids need to be collated to segments
  # So there's a big, untidy, inefficient sort by segment_id here
  #
  my $lastsegid = q();
  for my $feature (sort {
    $a->{'segment'} cmp $b->{'segment'}

  } map {
    $self->build_features({'group_id' => $_})

  } @{$opts->{'groups'}}) {

    if($feature->{'segment'} ne $lastsegid) {
      my $seg      = $feature->{'segment'}         || q();
      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || q();
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}   || q();
      my $segver   = $feature->{'segment_version'} || q(1.0);
      if($lastsegid) {
	$response   .= qq(    </SEGMENT>\n);
      }
      $response   .= qq(    <SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">\n);

      $lastsegid = $feature->{'segment'};
    }
    $response .= gen_feature_das_response($feature, q(    ));
  }

  if($lastsegid) {
    $response .= qq(    </SEGMENT>\n);
  }

  return $response;
}

sub error_feature {
  my ($self, $f) = @_;
  return qq(    <SEGMENT id=q()>
      <UNKNOWNFEATURE id="$f" />
    </SEGMENT>\n);
}

sub das_dna {
  my ($self, $segref) = @_;

  my $response = q();
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();
    my $segstart       = $start || $self->start($seg) || q();
    my $segend         = $end   || $self->end($seg)   || q();
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || q(1.0);
    my $len            = CORE::length $seq;
    $response         .= qq(  <SEQUENCE id="$seg" start="$segstart" stop="$segend" moltype="$moltype" version="$version">\n);
    $response         .= qq(  <DNA length="$len">\n$seq\n  </DNA>\n  </SEQUENCE>\n);
  }
  return $response;
}

sub das_sequence {
  my ($self, $segref) = @_;

  my $response = q();
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();
    my $segstart       = $start || $self->start($seg) || q();
    my $segend         = $end   || $self->end($seg)   || q();
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || q(1.0);
    my $len            = CORE::length($seq);
    $response         .= qq(  <SEQUENCE id="$seg" start="$segstart" stop="$segend" moltype="$moltype" version="$version">\n$seq\n</SEQUENCE>\n);
  }
  return $response;
}

sub das_types {
  my ($self, $opts) = @_;
  my $response      = q();
  my @types         = ();
  my $data          = {};

  if(!scalar @{$opts->{'segments'}}) {
    $data->{'anon'} = [];
    push @{$data->{'anon'}}, $self->build_types();

  } else {
    for my $seg (@{$opts->{'segments'}}) {
      my ($seg, $coords) = split /:/mx, $seg;
      my ($start, $end)  = split /,/mx, $coords || q();
      my $segstart       = $start || $self->start($seg) || q();
      my $segend         = $end   || $self->end($seg)   || q();

      $data->{$seg} = [];
      @types = $self->build_types({
				   'segment' => $seg,
				   'start'   => $start,
				   'end'     => $end,
				  });

      push @{$data->{$seg}}, @types;
    }
  }

  for my $seg (keys %{$data}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();
    my $segstart       = $start || $self->start($seg) || q();
    my $segend         = $end   || $self->end($seg)   || q();

    if ($seg ne 'anon') {
      $response .= qq(  <SEGMENT id="$seg" start="$segstart" stop="$segend" version="1.0">\n);

    } else {
      $response .= qq(  <SEGMENT version="1.0">\n);
    }

    for my $type (@{$data->{$seg}}) {
      $response .= sprintf qq(    <TYPE id="%s"%s%s%s%s%s%s>%s</TYPE>\n),
			   $type->{'type'}       || q(),
			   $type->{'method'}      ?qq( method="$type->{'method'}")           : q(),
			   $type->{'category'}    ?qq( category="$type->{'category'}")       : q(),
			   $type->{'c_ontology'}  ?qq( c_ontology="$type->{'c_ontology'}")   : q(),
			   $type->{'evidence'}    ?qq( evidence="$type->{'evidence'}")       : q(),
			   $type->{'e_ontology'}  ?qq( e_ontology="$type->{'e_ontology'}")   : q(),
			   $type->{'description'} ?qq( description="$type->{'description'}") : q(),
			   $type->{'count'}      || q();
    }
    $response .= qq(  </SEGMENT>\n);
  }
  return $response;
}

sub das_entry_points {
  my $self    = shift;
  my $content = q();

  for my $ep ($self->build_entry_points()) {
    my $subparts = $ep->{'subparts'} || 'yes'; # default to yes here as we're giving entrypoints
    $content    .= qq(    <SEGMENT id="$ep->{'segment'}" size="$ep->{'length'}" subparts="$subparts" />\n);
  }

  return $content;
}

sub das_stylesheet {
  my $self = shift;
  return $self->_plain_response('stylesheet') || qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd">
<DASSTYLE>
<STYLESHEET version="1.0">
  <CATEGORY id="default">
    <TYPE id="default">
      <GLYPH>
        <BOX>
          <FGCOLOR>black</FGCOLOR>
          <FONT>sanserif</FONT>
          <BUMP>0</BUMP>
          <BGCOLOR>black</BGCOLOR>
        </BOX>
      </GLYPH>
    </TYPE>
  </CATEGORY>
</STYLESHEET>
</DASSTYLE>\n);
}

sub das_homepage {
  my $self = shift;
  my $dsn  = $self->dsn() || q();
  my $mm   = $self->mapmaster() || $self->config->{'mapmaster'} || q();
  $mm      = $mm?qq(<a href="$mm">$mm</a>):'none configured';
  my $seg  = $self->config->{'example_segment'};

  return $self->_plain_response('homepage') || qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <title>ProServer: Source Information for $dsn</title>
<style type="text/css">
html,body{background:#ffc;font-family:helvetica,arial,sans-serif;}
thead{background-color:#700;color:#fff;}
thead th{margin:0;padding:2px;}
a{color:#a00;}a:hover{color:#aaa;}
</style>
  </head>
  <body>
    <h1>ProServer: Source Information for $dsn</h1>
    <dl>
      <dt>DSN</dt>
      <dd>$dsn</dd>
      <dt>Description</dt>
      <dd>@{[$self->description() || $self->config->{'description'} || 'none configured']}</dd>
      <dt>Mapmaster</dt>
      <dd>$mm</dd>
      <dt>Capabilities</dt>
      <dd>@{[map { my ($c) = $_ =~ m|(\w+)|;
                   if($seg && $c eq 'features') { $c = "$c?segment=$seg"; }
                   qq(<a href="$dsn/$c">$_</a>);
                 } split /;/mx, $self->das_capabilities()]}
    </dl>
  </body>
</html>\n);}

sub das_xsl {
  my ($self, $opts) = @_;
  my $call = $opts->{'call'};

  return q() if(!$call);
  my $response = $self->_plain_response("xsl_$call");
  if(!$response) {
    $response = $XSL->{$call};
    $response =~ s/<head>/<head>$XSLFLUFF/smix;
  }
  return $response;
}

sub _plain_response {
  my ($self, $cfghead) = @_;
  if(!$cfghead) {
    return q();
  }

  if($self->config->{$cfghead}) {
    #########
    # Inline homepage
    #
    return $self->config->{$cfghead};

  } elsif($self->config->{"${cfghead}file"}) {
    #########
    # import homepage file
    #
    my $filedata = $self->{"${cfghead}file"};
    if(!$filedata) {
      my ($fn) = $self->config->{"${cfghead}file"} =~ m|([a-z0-9_\./\-]+)|mix;
      eval {
	open my $fh, '<', $fn or croak "opening $cfghead '$fn': $!";
	local $RS = undef;
	$filedata = <$fh>;
	close $fh;
      };
      carp $EVAL_ERROR if($EVAL_ERROR);
    }

    if(($self->config->{"cache${cfghead}file"}||'yes') eq 'yes') {
      $self->{"${cfghead}file"} ||= $filedata;
    }

    $filedata and return $filedata;
  }
  return;
}

sub das_alignment {
  my ($self, $opts) = @_;
  my $response      = q();
  my $query         = $opts->{'query'};
  my $subjects_refs  = $opts->{'subjects'};
  my $sub_coos       = $opts->{'subcoos'} || q();
  my $rows          = $opts->{'rows'}    || q();

  #The build_alignment should be encoded by the SoureAdaptor subclasses
  for my $ali ($self->build_alignment($query, $rows, $subjects_refs, $sub_coos)) {
    $response .= sprintf qq(  <alignment name="%s" alignType="%s"%s%s>\n),
			 $ali->{'name'},
			 $ali->{'type'} || 'unknown',
			 $ali->{'max'}      ?qq( max="$ali->{'max'}"):q(),
			 $ali->{'position'} ?qq( position="$ali->{'position'}"):q();

    for my $ali_obj (grep { $_ } @{$ali->{'alignObj'}}) {
      $response .= _gen_align_object_response($ali_obj, q(   ));
    }

    for my $score (@{$ali->{'scores'}}) {
      $response .= _gen_align_score_response($score, q(   ));
    }

    for my $block (@{$ali->{'blocks'}}) {
      $response .= _gen_align_block_response($block, q(   ));
    }

    for my $geo3d (@{$ali->{'geo3D'}}) {
      $response .= _gen_align_geo3d_response($geo3d, q(   ));
    }
    $response .= qq (  </alignment>\n);
  }

  return $response;
}

sub _gen_align_object_response {
  my ($ali_obj, $spacing) = @_;
  my $children            = 0;

  my $response = sprintf q(%s  <alignObject objectVersion="%s" intObjectId="%s" %s dbSource="%s" dbVersion="%s" dbAccessionId="%s" %s>),
                         $spacing,
			 $ali_obj->{'version'}   || '1.0',
			 $ali_obj->{'intID'}     || 'unknown',
			 $ali_obj->{'type'}?qq(type="$ali_obj->{'type'}"):q(),
			 $ali_obj->{'dbSource'}  || 'unknown',
			 $ali_obj->{'dbVersion'} || 'unknown',
			 $ali_obj->{'accession'} || 'unknown',
			 $ali_obj->{'coos'}?qq(dbCoodSys="$ali_obj->{'coos'}"):q();

  for my $detail (@{$ali_obj->{'aliObjectDetail'}}) {
    $children++;
    $response .= sprintf qq(%s    <alignObjectDetail dbSource="%s" property="%s"%s>\n),
                         $spacing,
			 $detail->{'source'}   || 'unknown',
			 $detail->{'property'} || 'unknown',
			 $detail->{'detail'}?qq(>$detail->{'detail'}</alignObjectDetail):q(/);

  }

  #Finally if the sequence is present, add this
  if(my $seq = $ali_obj->{'sequence'}) {
    $children++;
    $response .= qq($spacing    <sequence>$seq</sequence>\n);
  }

  #Finish off the ALIGNOBLECT
  if($children) {
    $response .= qq($spacing  </alignObject>\n);

  } else {
     #bit of a hack, but makes nice well formed xml
    chop $response; # This will remove the >
    $response .= q(/>);
  }
  return $response;
}

sub _gen_align_score_response {
  my($score, $spacing) = @_;
  return sprintf qq(%s <score methodName="%s" value="%s" />\n),
                 $spacing,
                 $score->{'method'} || 'unknown',
		 $score->{'score'}  || '0';
}

sub _gen_align_block_response {
  my($block, $spacing) = @_;

  #########
  # The code assumes that if a block is passed in, it has an alignment
  # segment.  Although the code would not break, I doubt that it would validate
  # against the schema.
  #

  #########
  # Block tag with required and optional attributes
  #
  my $response .= sprintf qq(%s <block blockOrder="%s" %s>\n),
                  $spacing,
		  $block->{'blockOrder'} || 1,
		  $block->{'blockScore'}?qq(blockScore="$block->{'blockScore'}"):q();
  
  for my $segment (@{$block->{'segments'}}) {
    $response .= sprintf qq(%s  <segment intObjectId="%s"%s%s%s%s\n),
                         $spacing,
			 $segment->{'objectId'},
			 (exists $segment->{'start'})?qq( start="$segment->{'start'}"):q(),
			 (exists $segment->{'end'})  ?qq( end="$segment->{'end'}"):q(),
			 $segment->{'orientation'}?qq( orientation="$segment->{'orientation'}"):q(),
			 $segment->{'cigar'}?qq( >\n$spacing   <cigar>"$segment->{'cigar'}"</cigar>\n$spacing  </segment>):q(/>);
  }

  #########
  # close the block
  #
  $response .= qq($spacing </block>\n);
  return $response;
}

sub _gen_align_geo3d_response {
  my($geo3d, $spacing) = @_;

  #########
  # The geo3d is a reference to a 2D array.
  #
  my $response = q();
  my $id       = $geo3d->{'intObjectId'} || 'unknown';
  my $vector   = $geo3d->{'vector'};
  my $matrix   = $geo3d->{'matrix'};
  
  $response .= qq($spacing <geo3d intObjectId="$id">\n);

  if($vector && $matrix) { #These are both required
    my $x      = $vector->{'x'} || '0.0';
    my $y      = $vector->{'y'} || '0.0';
    my $z      = $vector->{'z'} || '0.0';
    $response .= qq($spacing  <vector x="$x" y="$y" z="$z" />\n);
    $response .= qq($spacing  <matrix>\n);

    for my $m1 (0,1,2) {
      for my $m2 (0,1,2) {
	my $coordinate = $matrix->[$m1]->[$m2] || '0.0';
	my $n1         = $m1 + 1;#Bit of a hack, but ensures data integrity between the array and xml with next to no effort.
	my $n2         = $m2 + 1;#ditto
	$response     .= qq($spacing    <max$n1$n2 coord="$coordinate" />\n);
      }
    }
    $response .= qq($spacing  </matrix>\n);
  }
  $response .= qq($spacing </geo3d>\n);
  return $response;
}


sub das_structure {
  my($self, $opts) = @_;
  my $response     = q();

  #Get the arguments
  my $query  = $opts->{'query'};
  my $chains = $opts->{'chains'} || undef;
  my $model  = $opts->{'model'}  || undef;

  #The build_structure should be specified by the sourceAdaptor subclass

  my $structure = $self->build_structure($query, $chains, $model);

  for my $obj (@{$structure->{'objects'}}) {
    $response .= _gen_object_response($obj, q( ));
  }

  for my $chain (@{$structure->{'chains'}}) {
    $response .= _gen_chain_response($chain, q( ));
  }

  for my $connect (@{$structure->{'connects'}}) {
    $response .= _gen_connect_response($connect, q( ));
  }

  return $response;
}

sub _gen_object_response {
  my ($object, $spacing) = @_;
  my $children           = 0;

  my $response .= sprintf q(%s <object objectVersion="%s"%sdbSource="%s" dbVersion="%s" dbAccessionId="%s" dbCoodSys="%s">),
                          $spacing,
			  $object->{'dbVersion'}     || '1.0',
			  $object->{'type'}?qq( type="$object->{'type'}" ):q(),
			  $object->{'dbSource'}      || 'unknown',
			  $object->{'dbVersion'}     || 'unknown',
			  $object->{'dbAccessionId'} || 'unknown',
			  $object->{'dbCoordSys'}    || 'pdb';

  for my $objDetail (@{$object->{'objectDetails'}}) {
    $children++;
    $response .= sprintf qq(%s   <objectDetail dbSource="%s" property="%s" %s>\n),
                         $spacing,
			 $objDetail->{'source'}   || 'unknown',
			 $objDetail->{'property'} || 'unknown',
			 $objDetail->{'detail'}?qq(>$objDetail->{'detail'}</objectDetail):q();

  }

  #########
  # Finish off the object
  #
  if($children) {
    $response .= qq($spacing  </object>);

  } else {
    #########
    # bit of a hack, but makes nice well formed xml
    # Remove the trailing '>' and self-close
    #
    chop $response;
    $response .= q(/>);
  }
  return $response;
}

sub _gen_chain_response {
  my ($chain, $spacing) = @_;

  #########
  # Set up the chain properties, chain id, swisprot mapping and model number.
  #
  my $id = $chain->{'id'} || q();
  if($id =~ /null/mx) {
    $id = q();
  }

  my $response .= sprintf qq(%s<chain id="%s" %s %s>\n),
                          $spacing,
			  $id,
		          $chain->{'modelNumber'}?qq(model="$chain->{'modelNumber'}"):q(),
		          $chain->{'SwissprotId'}?qq(SwissprotId="$chain->{'SwissprotId'}"):q();

  #########
  # Now add the "residues" to the chain
  #
  for my $group (@{$chain->{'groups'}}) {
    #########
    # Residue properties
    #
    $response .= sprintf qq(%s  <group type="%s" groupID="%s" name="%s" %s>\n),
                         $spacing,
			 $group->{'type'},
			 $group->{'id'},
			 $group->{'name'},
			 $group->{'icode'}?qq(insertCode="$group->{'icode'}"):q();

    #########
    # Add the atoms to the chain
    #
    for my $atom (@{$group->{'atoms'}}) {
      $response .= sprintf qq(%s    <atom x="%s" y="%s" z="%s" atomName="%s" atomID="%s" %s %s %s/>\n),
	                   $spacing,
			   (map { $atom->{$_} } qw(x y z atomName atomId)),
			   (map { $atom->{$_}?qq($_="$atom->{$_}"):q() } qw(occupancy tempFactor altLoc));

    }
    #close group tag
    $response .= qq($spacing   </group>\n); 
  }

  #close chain tag
  $response .= qq($spacing </chain>\n);
  return $response;
}

sub _gen_connect_response {
  my ($connect, $spacing) = @_;
  my $response     = q();
  my $atom_serial  = $connect->{'atomSerial'} || undef;
  my $connect_type = $connect->{'type'}       || 'unknown';

  if($atom_serial) {
    $response .= qq($spacing <connect atomSerial="$atom_serial" type="$connect_type">\n);

    for my $atom (@{$connect->{'atom_ids'}}) {
      $response .= qq($spacing   <atomid atomID="$atom"/>\n);
    }
    $response .= qq($spacing </connect>);
  }
  return $response;
}

sub cleanup {
  my $self  = shift;
  my $debug = $self->{'debug'};

  if(!$self->config->{'autodisconnect'}) {
    $debug and print {*STDERR} "${self}::cleanup retaining transport\n";
    return;

  } else {
    if(!$self->{'_transport'}) {
      $debug and print {*STDERR} "${self}::cleanup no transport loaded\n";
      return;
    }

    my $transport = $self->transport();
    if($self->config->{'autodisconnect'} eq 'yes') {
      eval {
	$self->transport->disconnect();
	$debug and print {*STDERR} qq(${self}::cleanup performed forced transport disconnect\n);
      };
    } elsif($self->config->{'autodisconnect'} =~ /(\d+)/mx) {
      if(time - $self->transport->init_time() > $1) {
	eval {
	  $self->transport->disconnect();
	  $debug and print {*STDERR} qq(${self}::cleanup performed timed transport disconnect\n);
	};
      }
    }
  }
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor - base class for sources

=head1 VERSION

$Revision: 2.59 $

=head1 SYNOPSIS

A base class implementing stubs for all SourceAdaptors.

=head1 DESCRIPTION

SourceAdaptor.pm generats XML and manages callouts for DAS request
handling.

If you're extending ProServer, this class is probably what you need to
inherit. The build_* methods are probably the ones you need to
extend. build_features() in particular.

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>

=head1 SUBROUTINES/METHODS

=head2 new : Constructor

  my $oSourceAdaptor = Bio::Das::ProServer::SourceAdaptor::<implementation>->new({
    'dsn'      => q(),
    'port'     => q(),
    'hostname' => q(),
    'config'   => q(),
    'debug'    => 1,
  });

  Generally this would only be invoked on a subclass

=head2 init : Post-construction initialisation, passed the first argument to new()

  $oSourceAdaptor->init();

=head2 length : Returns the segment-length given a segment

  my $sSegmentLength = $oSourceAdaptor->length('1:1,100000');

=head2 mapmaster : Mapmaster for this source. Overrides configuration 'mapmaster' setting

  my $sMapMaster = $oSourceAdaptor->mapmaster();

=head2 description : Description for this source. overrides configuration 'description' setting

  my $sDescription = $oSourceAdaptor->description();

=head2 build_features : (subclasses only) Fetch feature data

This call is made by das_features(). It is passed one of:

 { 'segment'    => $, 'start' => $, 'end' => $ }

 { 'feature_id' => $ }

 { 'group_id'   => $ }

 and is expected to return a reference to an array of hash references, i.e.
 [{},{}...{}]

Each hash returned represents a single feature and should contain a
subset of the following keys and types. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 start                         => $
 end                           => $
 note                          => $ or [$,$,$...]
 id       || feature_id        => $ 
 label    || feature_label     => $
 type                          => $ 
 typetxt                       => $ 
 method                        => $ 
 method_label                  => $ 
 group_id || group             => $ or [{
                                         grouplabel   => $,
                                         grouptype    => $,
                                         groupnote    => $,
                                         grouplink    => $,
                                         grouplinktxt => $,
                                         note         => $ or [$,$,$...],
                                         target       => [{
                                                            id        => $,
                                                            start     => $,
                                                            stop      => $,
                                                            targettxt => $,
                                                           }],
                                        },{}...]
 grouplabel                    => $
 grouptype                     => $
 groupnote                     => $
 grouplink                     => $
 grouplinktxt                  => $
 score                         => $
 ori                           => $
 phase                         => $
 link                          => $
 linktxt                       => $
 target                        => scalar or [{
                                              id        => $,
                                              start     => $,
                                              stop      => $,
                                              targettxt => $,
                                             },{}...]
 target_id                     => $
 target_start                  => $
 target_stop                   => $
 targettxt                     => $
 typecategory || type_category => $
 typesubparts                  => $
 typesuperparts                => $
 typereference                 => $

=head2 build_types : (Subclasses only) fetch type data

This call is made by das_types(). It is passed one of:

 [{ 'segment'    => $, 'start' => $, 'end' => $ }, {}...]

 { 'segment'    => $, 'start' => $, 'end' => $ }

 and is expected to return a reference to an array of hash references, i.e.
 [{},{}...{}]

Each hash returned represents a single type and should contain a
subset of the following keys and values. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 type        => $
 method      => $
 category    => $
 c_ontology  => $
 evidence    => $
 e_ontology  => $
 description => $
 count       => $

=head2 build_entry_points : (Subclasses only) fetch entry_points data

This call is made by das_entry_points(). It is not passed any args

and is expected to return a reference to an array of hash references, i.e.
 [{},{}...{}]

Each hash returned represents a single entry_point and should contain a
subset of the following keys and values. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 segment  => $
 length   => $
 subparts => $

=head2 init_segments : hook for optimising results to be returned.

  By default - do nothing
  Not necessary for most circumstances, but useful for deciding on what sort
  of coordinate system you return the results if more than one type is available.

  $self->init_segments() is called inside das_features() before build_features().

=head2 known_segments : returns a list of valid segments that this adaptor knows about

  my @aSegmentNames = $oSourceAdaptor->known_segments();

=head2 segment_version : gives the version of a segment (MD5 under certain circumstances) given a segment name

  my $sVersion = $oSourceAdaptor->segment_version($sSegment);

=head2 dsn : get accessor for this sourceadaptor's dsn

  my $sDSN = $oSourceAdaptor->dsn();

=head2 dsnversion : get accessor for this sourceadaptor's dsn version

  my $sDSNVersion = $oSourceAdaptor->dsnversion();

=head2 start : get accessor for segment start given a segment

  my $sStart = $oSourceAdaptor->start('DYNA_CHICK:35,127');

  Returns 1 by default

=head2 end : get accessor for segment end given a segment

  my $sEnd = $oSourceAdaptor->end('DYNA_CHICK:35,127');

=head2 transport : Build the relevant B::D::PS::SA::Transport::<...> configured for this adaptor

  my $oTransport = $oSourceAdaptor->transport();

=head2 config : get/set config settings for this adaptor

  $oSourceAdaptor->config($oConfig);

  my $oConfig = $oSourceAdaptor->config();

=head2 implements : helper to determine if an adaptor implements a request based on its capabilities

  my $bIsImplemented = $oSourceAdaptor->implements($sDASCall); # e.g. $sDASCall = 'sequence'

=head2 das_capabilities : DAS-response capabilities header support

  my $sHTTPHeader = $oSourceAdaptor->das_capabilities();

=head2 das_dsn : DAS-response for dsn request

  my $sXMLResponse = $sa->das_dsn();

=head2 open_dasdsn : DAS-response dsn xml leader

  my $sXMLResponse = $sa->open_dasdsn();

=head2 close_dasdsn : DAS-response dsn xml trailer

  my $sXMLResponse = $sa->close_dasdsn();

=head2 unknown_segment : DAS-response unknown segment error response

  my $sXMLResponse = $sa->unknown_segment();

=head2 das_features : DAS-response for 'features' request

  my $sXMLResponse = $sa->das_features();

=head2 error_feature : DAS-response unknown feature error

  my $sXMLResponse = $sa->error_feature();

=head2 das_dna : DAS-response for DNA request

  my $xml = $sa->das_dna();

=head2 das_sequence : DAS-response for sequence request

  my $sXMLResponse = $sa->das_sequence();

=head2 das_types : DAS-response for 'types' request

  my $sXMLResponse = $sa->das_types();

=head2 das_entry_points : DAS-response for 'entry_points' request

  my $sXMLResponse = $sa->das_entry_points();

=head2 das_stylesheet : DAS-response for 'stylesheet' request

  my $sXMLResponse = $sa->das_stylesheet();

=head2 das_homepage : DAS-response (non-standard) for 'homepage' request

  my $sHTMLResponse = $sa->das_homepage();

=head2 das_xsl : DAS-response (non-standard) for 'xsl' request

  my $sXSLResponse = $sa->das_xsl();

=head2 das_alignment

 Title    : das_alignment
 Function : This produces the das repsonse for an alignment
 Args     : query options
 returns  : string containing Das repsonse for the alignment

 Example Response:
<alignment>
  <alignObject>
    <alignObjectDetail />
    <sequence />
  </alignObject>
  <score/>
  <block>
    <segment>
      <cigar />
    </segment>
  </block>
  <geo3D>
    <matrix>
      <max11 coord="float" />
      <max12 coord="float" />
      <max13 coord="float" />
      <max21 coord="float" />
      <max22 coord="float" />
      <max23 coord="float" />
      <max31 coord="float" />
      <max32 coord="float" />
      <max33 coord="float" />
    </matrix>
  </geo3D>	
</alignment>

=head2 _gen_align_object_response

 Title    : _gen_align_object_response
 Function : Formats the supplied alignment object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasalignment xml
 Args     : align data structure, spacing string
 Returns  : Das Response string encapuslating aliObject

=head2 _gen_align_score_response

 Title   : _gen_align_score_response
 Function: The takes an input score data structure and arbitrary spacing 
         : for pretty printing and converts the data structure into 
         : dasalignment xml
 Args    : score data structure, spacing string
 Returns : Das Response string from alignment score

=head2 _gen_align_block_response

 Title   : _gen_align_block_response
 Function: The takes an input block data structure and arbitrary spacing 
         : for pretty printing and converts the block data structure into 
         : dasalignment xml
 Args    : block data structure, spacing string
 Returns : Das Response string from alignmentblock

=head2 _gen_align_geo3d_response

  Title    : genAlignGeo3d
  Function : Takes a geo3d data structure and arbitrary spacing for pretty printing and convertis it into DAS repsonse XML that represents the alignment matrix.
  Args     : data structure containing the vector and matrix, spacing string
  Returns  : String containing the DAS response xml

=head2 das_structure 

 Title    : das_structure
 Function : This produces the das repsonse for a pdb structure
 Args     : query options.  Currently, this will that query, chain and modelnumber.
          : The only part of the specification that this does not adhere to is the range argument. 
          : However, I think this argument is a potential can of worms!
 returns  : string containing Das repsonse for the pdb structure
 comment  : See http://www.efamily.org.uk/xml/das/documentation/structure.shtml for more information 
          : on the das structure specification.

 Example Response:
<object dbAccessionId="1A4A" intObjectId="1A4A" objectVersion="29-APR-98" type="protein structure" dbSource="PDB" dbVersion="20040621" dbCoordSys="PDBresnum" />
<chain id="A" SwissprotId="null">
  <group name="ALA" type="amino" groupID="1">
    <atom atomID="1" atomName=" N  " x="-19.031" y="16.695" z="3.708" />
    <atom atomID="2" atomName=" CA " x="-20.282" y="16.902" z="4.404" />
    <atom atomID="3" atomName=" C  " x="-20.575" y="18.394" z="4.215" />
    <atom atomID="4" atomName=" O  " x="-20.436" y="19.194" z="5.133" />
    <atom atomID="5" atomName=" CB " x="-20.077" y="16.548" z="5.883" />
    <atom atomID="6" atomName="1H  " x="-18.381" y="17.406" z="4.081" />
    <atom atomID="7" atomName="2H  " x="-18.579" y="15.781" z="3.874" />
    <atom atomID="8" atomName="3H  " x="-19.018" y="16.844" z="2.68" />
  </group>
  <group name="HOH" type="hetatm" groupID="219">
    <atom atomID="3057" atomName=" O  " x="-17.904" y="13.635" z="-7.538" />
    <atom atomID="3058" atomName="1H  " x="-18.717" y="14.098" z="-7.782" />
    <atom atomID="3059" atomName="2H  " x="-17.429" y="13.729" z="-8.371" />
  </group>
</chain>
<connect atomSerial="26" type="bond">
  <atomID atomID="25" />
  <atomID atomID="242" />
</connect>

=head2 _gen_object_response

 Title    : _gen_object_response
 Function : Formats the supplied structure object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : object data structure, spacing string
 Returns  : Das Response string encapuslating 'object'
 Comment  : The object response allows the details of the coordinates to be descriped. For example
          : the fact that the coos are part of a pdb file.

=head2 _gen_chain_response

 Title    : _gen_chain_response
 Function : Formats the supplied chain object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : chain data structure, spacing string
 Returns  : Das Response string encapuslating 'chain'
 Comment  : Chain objects contain all of the atom positions (including hetatoms).
          : The groups are typically residues or ligands.

=head2 _gen_connect_response

 Title    : _gen_connect_response
 Function : Formats the supplied connect data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : connect data structure, spacing string
 Returns  : Das Response string encapuslating "connect"
 Comment  : Such objects are specified to enable groups of atoms to be connected together.

=head2 cleanup : Post-request garbage collection

=head1 CONFIGURATION AND ENVIRONMENT

Used within Bio::Das::ProServer::Config, eg/proserver and of course all subclasses.

=head1 DIAGNOSTICS

set $self->{'debug'} = 1

=head1 DEPENDENCIES

HTML::Entities

=head1 INCOMPATIBILITIES

None reported

=head1 BUGS AND LIMITATIONS

None reported

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
