#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2005-11-28
#
# Generic SourceAdaptor. Generates XML and manages callouts for DAS functions
#
package Bio::Das::ProServer::SourceAdaptor;
use strict;
use HTML::Entities;

our $VERSION  = do { my @r = (q$Revision: 2.01 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

=head2 new : Constructor

  my $oSourceAdaptor = Bio::Das::ProServer::SourceAdaptor::<implementation>->new({
    'dsn'      => '',
    'port'     => '',
    'hostname' => '',
    'config'   => '',
    'debug'    => 1,
  });

  Generally this would only be invoked on a subclass

=cut
sub new {
  my ($class, $defs) = @_;
  my $self = {
	      'dsn'          => $defs->{'dsn'},
	      'port'         => $defs->{'port'},
	      'hostname'     => $defs->{'hostname'},
	      'config'       => $defs->{'config'},
	      'debug'        => $defs->{'debug'}    || undef,
	      '_data'        => {},
	      '_sequence'    => {},
	      '_features'    => {},
	      'capabilities' => {
				 'dsn' => "1.0",
				},
	     };

  bless $self, $class;
  $self->init($defs);

  if(!exists($self->{'capabilities'}->{'stylesheet'}) &&
     ($self->{'config'}->{'stylesheet'} ||
      $self->{'config'}->{'stylesheetfile'})) {
    $self->{'capabilities'}->{'stylesheet'} = "1.0";
  }
  return $self;
}

=head2 init : Post-construction initialisation, passed the first argument to new()

  $oSourceAdaptor->init();

=cut
sub init {};

=head2 length : Returns the segment-length given a segment

  my $sSegmentLength = $oSourceAdaptor->length("1:1,100000");

=cut
sub length { 0; }

=head2 mapmaster :  Mapmaster for this source. Overrides configuration 'mapmaster' setting

  my $sMapMaster = $oSourceAdaptor->mapmaster();

=cut
sub mapmaster {}

=head2 description : Description for this source. overrides configuration 'description' setting

  my $sDescription = $oSourceAdaptor->description();

=cut
sub description {}

=head2 init_segments : hook for optimising results to be returned.

  By default - do nothing
  Not necessary for most circumstances, but useful for deciding on what sort
  of coordinate system you return the results if more than one type is available.

  $self->init_segments() is called before building features.
=cut
sub init_segments {}

=head2 known_segments : returns a list of valid segments that this adaptor knows about

  my @aSegmentNames = $oSourceAdaptor->known_segments();

=cut
sub known_segments {}

=head2 segment_version : gives the version of a segment (MD5 under certain circumstances) given a segment name

  my $sVersion = $oSourceAdaptor->segment_version($sSegment);

=cut
sub segment_version {}

=head2 dsn : get accessor for this sourceadaptor's dsn

  my $sDSN = $oSourceAdaptor->dsn();

=cut
sub dsn {
  my $self = shift;
  return $self->{'dsn'} || "unknown";
};

=head2 dsnversion : get accessor for this sourceadaptor's dsn version

  my $sDSNVersion = $oSourceAdaptor->dsnversion();

=cut
sub dsnversion {
  my $self = shift;
  return $self->{'dsnversion'} || "1.0";
};

=head2 start : get accessor for segment start given a segment

  my $sStart = $oSourceAdaptor->start("DYNA_CHICK:35,127");

  Returns 1 by default

=cut
sub start { 1; }

=head2 end : get accessor for segment end given a segment

  my $sEnd = $oSourceAdaptor->end("DYNA_CHICK:35,127");

=cut
sub end {
  my $self = shift;
  return $self->length(@_);
}

=head2 transport : Build the relevant B::D::PS::SA::Transport::<...> configured for this adaptor

  my $oTransport = $oSourceAdaptor->transport();

=cut
sub transport {
  my $self = shift;

  if(!exists $self->{'_transport'}) {
    my $transport = "Bio::Das::ProServer::SourceAdaptor::Transport::".$self->config->{'transport'};
    eval "require $transport";
    if($@) {
      warn $@;

    } else {
      $self->{'_transport'} = $transport->new({
					       'dsn'    => $self->{'dsn'}, # for debug purposes
					       'config' => $self->config(),
					      });
    }
  }
  return $self->{'_transport'};
}

=head2 config : get/set config settings for this adaptor

  $oSourceAdaptor->config($oConfig);

  my $oConfig = $oSourceAdaptor->config();

=cut
sub config {
  my ($self, $config) = @_;
  $self->{'config'}   = $config if($config);
  return $self->{'config'};
}

=head2 implements : helper to determine if an adaptor implements a request based on its capabilities

  my $bIsImplemented = $oSourceAdaptor->implements($sDASCall); # e.g. $sDASCall = 'sequence'

=cut
sub implements {
  my ($self, $method) = @_;
  return $method?(exists $self->{'capabilities'}->{$method}):undef;
}

=head2 das_capabilities : DAS-response capabilities header support

  my $sHTTPHeader = $oSourceAdaptor->das_capabilities();

=cut
sub das_capabilities {
  my $self = shift;
  return join('; ', map {
    "$_/$self->{'capabilities'}->{$_}"
  } grep {
    defined $self->{'capabilities'}->{$_}
  } keys %{$self->{'capabilities'}});
}

=head2 das_dsn : DAS-response for dsn request

  my $sXMLResponse = $sa->das_dsn();

=cut
sub das_dsn {
  my $self    = shift;
  my $port    = $self->{'port'}?":$self->{'port'}":"";
  my $host    = $self->{'hostname'}||"";
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

=head2 open_dasdsn : DAS-response dsn xml leader

  my $sXMLResponse = $sa->open_dasdsn();

=cut
sub open_dasdsn {
  qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASDSN SYSTEM 'http://www.biodas.org/dtd/dasdsn.dtd' >
<DASDSN>\n);
}

=head2 close_dasdsn : DAS-response dsn xml trailer

  my $sXMLResponse = $sa->close_dasdsn();

=cut
sub close_dasdsn {
  qq(</DASDSN>\n);
}

=head2 open_dasgff : DAS-response feature xml leader

  my $sXMLResponse = $sa->open_dasgff();

=cut
sub open_dasgff {
  my ($self) = @_;
  my $host   = $self->{'hostname'};
  my $port   = $self->{'port'}?":$self->{'port'}":"";
  my $dsn    = $self->dsn();

  return qq(<?xml version="1.0" standalone="yes"?>
<!DOCTYPE DASGFF SYSTEM "http://www.biodas.org/dtd/dasgff.dtd">
<DASGFF>
  <GFF version="1.01" href="http://$host$port/das/$dsn/features">\n);
}

=head2 close_dasgff : DAS-response feature xml trailer

  my $sXMLResponse = $sa->close_dasgff();

=cut
sub close_dasgff {
  qq(  </GFF>
</DASGFF>\n);
}

=head2 unknown_segment : DAS-response unknown segment error response

  my $sXMLResponse = $sa->unknown_segment();

=cut
sub unknown_segment {
  my ($self, $seg) = @_;
  qq(    <UNKNOWNSEGMENT id="$seg" />\n);
}

#########
# code refactoring function to generate the link parts of the DAS response
#
sub _gen_link_das_response {
  my ($self, $link, $linktxt, $spacing) = @_;
  my $response = "";

  #########
  # if $link is a reference to and array or hash use their contents as multiple links
  #
  if(ref($link) eq "ARRAY") {
    while(my $k = shift @{$link}) {
      my $v;
      $v         = shift @{$linktxt} if(ref($linktxt) eq "ARRAY");
      $v       ||= $linktxt;
      $response .= qq($spacing<LINK href="$k">$v</LINK>\n);
    }

  } elsif(ref($link) eq "HASH") {
    while(my ($k, $v) = each %$link) {
      $response .= qq($spacing<LINK href="$k">$v</LINK>\n);
    }

  } elsif($link) {
    $response .= qq($spacing<LINK href="$link">$linktxt</LINK>\n)    if($link  ne "");
  }
  return $response;
}

#########
# Apply entity escaping
#
sub _encode {
  my ($self, $datum) = @_;
  return if(!ref($datum));

  if(ref($datum) eq "HASH") {
    while(my ($k, $v) = each %$datum) {
      if(ref($v)) {
	$self->_encode($v);
      } else {
	$datum->{$k} = &encode_entities($v);
      }
    }

  } elsif(ref($datum) eq "ARRAY") {
    @{$datum} = map { &encode_entities($_); } @{$datum};

  } elsif(ref($datum) eq "SCALAR") {
    $$datum = &encode_entities($$datum);
  }
}

#########
# code refactoring function to generate the feature parts of the DAS response
#
sub _gen_feature_das_response {
  my ($self, $feature, $spacing) = @_;
  $self->_encode($feature);

  my $response  = "";
  my $start     = $feature->{'start'}        || "0";
  my $end       = $feature->{'end'}          || "0";
  my $note      = $feature->{'note'}         || "";
  my $id        = $feature->{'id'}           || $feature->{'feature_id'}    || "";
  my $label     = $feature->{'label'}        || $feature->{'feature_label'} || $id;
  my $type      = $feature->{'type'}         || "";
  my $typetxt   = $feature->{'typetxt'}      || $type;
  my $method    = $feature->{'method'}       || "";
  my $method_l  = $feature->{'method_label'} || $method;
  my $group     = $feature->{'group'}        || "";
  my $glabel    = $feature->{'grouplabel'}   || "";
  my $gtype     = $feature->{'grouptype'}    || "";
  my $gnote     = $feature->{'groupnote'}    || "";
  my $glink     = $feature->{'grouplink'}    || "";
  my $glinktxt  = $feature->{'grouplinktxt'} || "";
  my $score     = $feature->{'score'}        || "";
  my $ori       = $feature->{'ori'}          || "0";
  my $phase     = $feature->{'phase'}        || "";
  my $link      = $feature->{'link'}         || "";
  my $linktxt   = $feature->{'linktxt'}      || $link;
  my $target    = $feature->{'target'}       || "";
  my $cat       = defined($feature->{'typecategory'})?qq(category="$feature->{'typecategory'}"):defined($feature->{'type_category'})?qq(category="$feature->{'type_category'}"):"";
  my $subparts  = $feature->{'typesubparts'}    || "no";
  my $supparts  = $feature->{'typessuperparts'} || "no";
  my $ref       = $feature->{'typesreference'}  || "no";
  $response    .= qq($spacing<FEATURE id="$id" label="$label">\n);
  $response    .= qq($spacing  <TYPE id="$type" $cat reference="$ref" subparts="$subparts" superparts="$supparts">$typetxt</TYPE>\n);
  $response    .= qq($spacing  <METHOD id="$method">$method_l</METHOD>\n) if($method ne "");
  $response    .= qq($spacing  <START>$start</START>\n);
  $response    .= qq($spacing  <END>$end</END>\n);
  $response    .= qq($spacing  <SCORE>$score</SCORE>\n)                 if($score ne "");
  $response    .= qq($spacing  <ORIENTATION>$ori</ORIENTATION>\n)       if($ori   ne "");
  $response    .= qq($spacing  <PHASE>$phase</PHASE>\n)                 if($phase ne "");

  # Allow the 'note' tag to point to an array of notes.
  if ( ref $note eq 'ARRAY' ) {
    for my $n (@$note) {
      next if (!$n);
      $response .= qq($spacing  <NOTE>$n</NOTE>\n);
    }

  } else {
    $response .= qq($spacing  <NOTE>$note</NOTE>\n)
      if ($note ne "");
  }

  # Allow the 'target' tag to be an array of hashes:
  # {
  #     'id'    => 'target ID',
  #     'start' => 'target start',
  #     'stop'  => 'target stop'
  # }

  if ($target && ref $target eq 'ARRAY') {
    for my $t (@$target) {
      $response .= sprintf(qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
			   $t->{'id'}    ?qq( id="$t->{'id'}")       :"",
			   $t->{'start'} ?qq( start="$t->{'start'}") :"",
			   $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :"",
			   $t->{'targettxt'} || $t->{'target'} || sprintf("%s:%d,%d", $t->{'id'}, $t->{'start'}, $t->{'stop'}));
    }

  } elsif($feature->{'target_id'}) {
    $response .= sprintf(qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
			 $feature->{'target_id'}    ?qq( id="$feature->{'target_id'}")       :"",
			 $feature->{'target_start'} ?qq( start="$feature->{'target_start'}") :"",
			 $feature->{'target_stop'}  ?qq( stop="$feature->{'target_stop'}")   :"",
			 $feature->{'targettxt'} || $feature->{'target_id'} || $feature->{'target'} ||
			 sprintf("%s:%d,%d", $feature->{'target_id'}, $feature->{'target_start'}, $feature->{'target_stop'}));
  }

  $response .= $self->_gen_link_das_response($link, $linktxt, "$spacing  ");

  #####
  # if $group is a ref to an array then use group_id of the hashs in that array as the key in a new hash
  #
  if (ref($group)eq "ARRAY") {
    my %groups=();
    for my $group (@{$group}) {
      $groups{$group->{'group_id'}} = $group;
    }
    $group = \%groups;
  }

  #########
  # if $group is a hash reference treat its keys as the multiple groups to be reported for this feature
  #
  my %groups = (ref($group)eq "HASH"?%{$group}:($group => {
							   'grouplabel'   => $glabel,
							   'grouptype'    => $gtype,
							   'groupnote'    => $gnote,
							   'grouplink'    => $glink,
							   'grouplinktxt' => $glinktxt,
							  }));

  for my $groupi (grep { substr($_, 0, 1) ne "_" } keys %groups) {
    if($groupi ne "") {
      my $groupinfo = $groups{$groupi};
      my $gnotei    = $groupinfo->{'groupnote'}	  || "";
      my $glinki    = $groupinfo->{'grouplink'}   || "";
      my $gtargeti  = $groupinfo->{'grouptarget'} || "";
      $response    .= sprintf(qq($spacing  <GROUP id="%s"%s%s),
			      $groupi,
			      $groupinfo->{'grouplabel'} ?qq( label="$groupinfo->{'grouplabel'}") :"",
			      $groupinfo->{'grouptype'}  ?qq( type="$groupinfo->{'grouptype'}")   :"");

      if (($gnotei eq "") && ($glinki eq "")) {
        $response .= qq(/>\n);

      } else {
        my $glinktxti = $groupinfo->{'grouplinktxt'} || $glinki;
        $response    .= qq(>\n);

	# Allow the 'note' tag to point to an array of notes.
	if ( ref $gnotei eq 'ARRAY' ) {
	  for my $n (@$gnotei) {
	    next if ( $n eq "" );
	    $response .= qq($spacing  <NOTE>$n</NOTE>\n);
	  }

	} else {
	  $response .= qq($spacing  <NOTE>$gnotei</NOTE>\n) if ($gnotei ne "");
	}
        $response .= $self->_gen_link_das_response($glinki, $glinktxti, "$spacing  ");

	if (ref $gtargeti eq 'ARRAY') {
	  for my $t (@$gtargeti) {
	    $response .= sprintf(qq($spacing  <TARGET%s%s%s>%s</TARGET>\n),
				 $t->{'id'}    ?qq( id="$t->{'id'}")       :"",
				 $t->{'start'} ?qq( start="$t->{'start'}") :"",
				 $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :"",
				 $t->{'targettxt'} || $t->{'target'} || sprintf("%s:%d,%d", $t->{'id'}, $t->{'start'}, $t->{'stop'}));
	  }
	}

        $response    .= qq($spacing  </GROUP>\n);
      }
    }
  }

  $response .= qq($spacing</FEATURE>\n);
  return $response;
}

=head2 das_features : DAS-response for 'features' request

  my $sXMLResponse = $sa->das_features();

=cut
sub das_features {
  my ($self, $opts) = @_;
  my $response      = "";

  $self->init_segments($opts->{'segments'});

  #########
  # features on segments
  #
  for my $seg (@{$opts->{'segments'}}) {
    my ($seg, $coords) = split(':', $seg);
    my ($start, $end)  = split(',', $coords||"");
    my $segstart       = $start || $self->start($seg) || "";
    my $segend         = $end   || $self->end($seg)   || "";

    if ( $self->known_segments() ) {
      unless (grep { /$seg/ } $self->known_segments()) {
	$response .= $self->unknown_segment($seg);
	next;
      }
    }

    my $segment_version = $self->segment_version($seg) ||  "1.0";
    $response          .= qq(    <SEGMENT id="$seg" version="$segment_version" start="$segstart" stop="$segend">\n);

    for my $feature ($self->build_features({
					    'segment' => $seg,
					    'start'   => $start,
					    'end'     => $end,
					   })) {
      $response .= $self->_gen_feature_das_response($feature, "    ");
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
      my $seg      = $feature->{'segment'}         || "";
      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || "";
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}	  || "";
      my $segver   = $feature->{'segment_version'} || "1.0";
      $response   .= qq(    <SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">\n);
      $response   .= $self->_gen_feature_das_response($feature, "    ");
      $response   .= qq(    </SEGMENT>\n);
    }
  }

  #########
  # features by group id
  # Responses across multiple group_ids need to be collated to segments
  # So there's a big, untidy, inefficient sort by segment_id here
  #
  my $lastsegid = "";
  for my $feature (sort {
    $a->{'segment'} cmp $b->{'segment'}

  } map {
    $self->build_features({'group_id' => $_})

  } @{$opts->{'groups'}}) {

    if($feature->{'segment'} ne $lastsegid) {
      my $seg      = $feature->{'segment'}         || "";
      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || "";
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}	  || "";
      my $segver   = $feature->{'segment_version'} || "1.0";
      $response   .= qq(    </SEGMENT>\n) if($lastsegid);
      $response   .= qq(    <SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">\n);

      $lastsegid = $feature->{'segment'};
    }
    $response .= &gen_feature_das_response($feature, "    ");
  }
  $response .= qq(    </SEGMENT>\n) if($lastsegid);

  return $response;
}

=head2 error_feature : DAS-response unknown feature error

  my $sXMLResponse = $sa->error_feature();

=cut
sub error_feature {
  my ($self, $f) = @_;
  qq(    <SEGMENT id="">
      <UNKNOWNFEATURE id="$f" />
    </SEGMENT>\n);
}

=head2 open_dasdna : DAS-response DNA leader

  my $xml = $sa->open_dasdna();

=cut
sub open_dasdna {
  qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASDNA SYSTEM "http://www.biodas.org/dtd/dasdna.dtd">
<DASDNA>\n);
}

=head2 open_dassequence : DAS-response sequence leader

  my $sXMLResponse = $sa->open_dassequence();

=cut
sub open_dassequence {
  qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASSEQUENCE SYSTEM "http://www.biodas.org/dtd/dassequence.dtd">
<DASSEQUENCE>\n);
}

=head2 das_dna : DAS-response for DNA request

  my $xml = $sa->das_dna();

=cut
sub das_dna {
  my ($self, $segref) = @_;

  my $response = "";
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split(':', $seg);
    my ($start, $end)  = split(',', $coords||"");
    my $segstart       = $start || $self->start($seg) || "";
    my $segend         = $end   || $self->end($seg)   || "";
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || "1.0";
    my $len            = CORE::length($seq);
    $response         .= qq(  <SEQUENCE id="$seg" start="$segstart" stop="$segend" moltype="$moltype" version="$version">\n);
    $response         .= qq(  <DNA length="$len">\n$seq\n  </DNA>\n  </SEQUENCE>\n);
  }
  return $response;
}

=head2 das_sequence : DAS-response for sequence request

  my $sXMLResponse = $sa->das_sequence();

=cut
sub das_sequence {
  my ($self, $segref) = @_;

  my $response = "";
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split(':', $seg);
    my ($start, $end)  = split(',', $coords||"");
    my $segstart       = $start || $self->start($seg) || "";
    my $segend         = $end   || $self->end($seg)   || "";
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || "1.0";
    my $len            = CORE::length($seq);
    $response         .= qq(  <SEQUENCE id="$seg" start="$segstart" stop="$segend" moltype="$moltype" version="$version">\n$seq\n</SEQUENCE>\n);
  }
  return $response;
}

=head2 close_dasdna : DAS-response DNA xml trailer

  my $xml = $sa->close_dasdna();

=cut
sub close_dasdna {
  qq(</DASDNA>\n);
}

=head2 close_dassequence : DAS-response sequence xml trailer

  my $xml = $sa->close_dassequence();

=cut
sub close_dassequence {
  qq(</DASSEQUENCE>\n);
}

=head2 open_dastypes : DAS-response types xml leader

  my $sXMLResponse = $sa->open_dastypes();

=cut
sub open_dastypes {
  my $self = shift;
  my $dsn  = $self->dsn();
  my $host = $self->{'hostname'}||"";
  my $port = $self->{'port'}?":$self->{'port'}":"";

  qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASTYPES SYSTEM "http://www.biodas.org/dtd/dastypes.dtd">
<DASTYPES>
  <GFF version="1.0" href="http://$host$port/das/$dsn/types">\n);
}

=head2 close_dastypes : DAS-response types xml trailer

  my $sXMLResponse = $sa->close_dastypes();

=cut
sub close_dastypes {
  qq(</GFF>
</DASTYPES>\n);
}

=head2 das_types : DAS-response for 'types' request

  my $sXMLResponse = $sa->das_types();

=cut
sub das_types {
  my ($self, $opts) = @_;
  my $response      = "";
  my @types         = ();
  my $data          = {};

  unless (@{$opts->{'segments'}}) {
    $data->{'anon'} = [];
    push (@{$data->{'anon'}},$self->build_types());

  } else {
    for my $seg (@{$opts->{'segments'}}) {
      my ($seg, $coords) = split(':', $seg);
      my ($start, $end)  = split(',', $coords||"");
      my $segstart       = $start || $self->start($seg) || "";
      my $segend         = $end   || $self->end($seg)   || "";

      $data->{$seg} = [];
      @types = $self->build_types({
				   'segment' => $seg,
				   'start'   => $start,
				   'end'     => $end,
				  });

      push (@{$data->{$seg}}, @types);
    }
  }

  for my $seg (keys %{$data}) {
    my ($seg, $coords) = split(':', $seg);
    my ($start, $end)  = split(',', $coords || "");
    my $segstart       = $start || $self->start($seg) || "";
    my $segend         = $end   || $self->end($seg)   || "";

    if ($seg ne "anon") {
      $response .= qq(  <SEGMENT id="$seg" start="$segstart" stop="$segend" version="1.0">\n);

    } else {
      $response .= qq(  <SEGMENT version="1.0">\n);
    }

    for my $type (@{$data->{$seg}}) {
      $response .= sprintf(qq(    <TYPE id="%s"%s%s%s%s%s%s>%s</TYPE>\n),
			   $type->{'type'}       || "",
			   $type->{'method'}      ?qq( method="$type->{'method'}")           : "",
			   $type->{'category'}    ?qq( category="$type->{'category'}")       : "",
			   $type->{'c_ontology'}  ?qq( c_ontology="$type->{'c_ontology'}")   : "",
			   $type->{'evidence'}    ?qq( evidence="$type->{'evidence'}")       : "",
			   $type->{'e_ontology'}  ?qq( e_ontology="$type->{'e_ontology'}")   : "",
			   $type->{'description'} ?qq( description="$type->{'description'}") : "",
			   $type->{'count'}      || "");
    }
    $response .= qq(  </SEGMENT>\n);
  }
  return $response;
}

=head2 open_dasep : DAS-response entry_points xml leader

  my $sXMLResponse = $sa->open_dasep();

=cut
sub open_dasep {
  my $self    = shift;
  my $dsn     = $self->dsn();
  my $host    = $self->{'hostname'}||"";
  my $port    = $self->{'port'}?":$self->{'port'}":"";

  return qq(<?xml version="1.0" standalone="no"?>
<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dasep.dtd">
<DASEP>
  <ENTRY_POINTS href="http://$host$port/das/$dsn/entry_points" version="1.0">\n);
}

=head2 close_dasep : DAS-response entry_points xml trailer

  my $sXMLResponse = $sa->close_dasep();

=cut
sub close_dasep {
  qq(  </ENTRY_POINTS>
</DASEP>\n);
}

=head2 das_entry_points : DAS-response for 'entry_points' request

  my $sXMLResponse = $sa->das_entry_points();

=cut
sub das_entry_points {
  my $self    = shift;
  my $content = "";

  for my $ep ($self->build_entry_points()) {
    my $subparts = $ep->{'subparts'} || "yes"; # default to yes here as we're giving entrypoints
    $content    .= qq(    <SEGMENT id="$ep->{'segment'}" size="$ep->{'length'}" subparts="$subparts" />\n);
  }

  return $content;
}

=head2 das_stylesheet : DAS-response for 'stylesheet' request

  my $sXMLResponse = $sa->das_stylesheet();

=cut
sub das_stylesheet {
  my $self = shift;
  if($self->config->{'stylesheet'}) {
    #########
    # Inline stylesheet
    #
    return $self->config->{'stylesheet'};

  } elsif($self->config->{'stylesheetfile'}) {
    #########
    # import stylesheet file
    #
    my $ssf = $self->{'stylesheetfile'};
    unless($ssf) {
      my ($fn) = $self->config->{'stylesheetfile'} =~ m|([a-z0-9_\./\-]+)|i;
      eval {
	my $fh;
	open($fh, $fn) or die "opening stylesheet '$fn': $!";
	local $/ = undef;
	$ssf     = <$fh>;
	close($fh);
      };
      warn $@ if($@);
    }

    if(($self->config->{'cachestylesheetfile'} || "yes") eq "yes") {
      $self->{'stylesheetfile'} ||= $ssf;
    }

    $ssf and return $ssf;
  }

  return qq(<?xml version="1.0" standalone="yes"?>
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

=head2 das_homepage : DAS-response (non-standard) for 'homepage' request

  my $sHTMLResponse = $sa->das_homepage();

=cut
sub das_homepage {
  my $self = shift;
  if($self->config->{'homepage'}) {
    #########
    # Inline homepage
    #
    return $self->config->{'homepage'};

  } elsif($self->config->{'homepagefile'}) {
    #########
    # import homepage file
    #
    my $hpf = $self->{'homepagefile'};
    unless($hpf) {
      my ($fn) = $self->config->{'homepagefile'} =~ m|([a-z0-9_\./\-]+)|i;
      eval {
	my $fh;
	open($fh, $fn) or die "opening homepage '$fn': $!";
	local $/ = undef;
	$hpf     = <$fh>;
	close($fh);
      };
      warn $@ if($@);
    }

    if(($self->config->{'cachehomepagefile'}||"yes") eq "yes") {
      $self->{'homepagefile'} ||= $hpf;
    }

    $hpf and return $hpf;
  }

  my $dsn = $self->dsn();

  return qq(<html>
  <head>
    <title>Source Information for $dsn</title>
  </head>
  <body>
    <h1>Source Information for $dsn</h1>
    <dl>
      <dt>DSN</dt>
      <dd>$dsn</dd>
      <dt>Description</dt>
      <dd>@{[$self->description() || $self->config->{'description'} || "none configured"]}</dd>
      <dt>Mapmaster</dt>
      <dd>@{[$self->mapmaster() || $self->config->{'mapmaster'} || "none configured"]}</dd>
      <dt>Capabilities</dt>
      <dd>@{[$self->das_capabilities()]}
  </body>
</html>\n);
}

=head2 das_alignment 

 Title    : das_alignment
 Function : This produces the das repsonse for an alignment
 Args     : query options
 returns  : string containing Das repsonse for the alignment 

=cut

sub das_alignment {
  my ($self, $opts) = @_;
  my $response      = "";
  my $query         = $opts->{'query'};
  my $subjectsRefs  = $opts->{'subjects'};
  my $subCoos       = $opts->{'subcoos'} || "";
  my $rows          = $opts->{'rows'}    || "";
  
  #Overview of the alignment structure
  #<alignment>
  #  <alignObject>
  #    <alignObjectDetail/>
  #    <sequence/>
  #  </alignObject>
  #  <score/>
  #  <block>
  #    <segment>
  #      <cigar/>
  #    </segment>
  #  </block>
  #  <geo3D>
  #    <matrix>
  #      <max11 coord="float"/>
  #      <max12 coord="float"/>
  #      <max13 coord="float"/>
  #	 <max21 coord="float"/>
  #	 <max22 coord="float"/>
  #	 <max23 coord="float"/>
  #	 <max31 coord="float"/>
  #	 <max32 coord="float"/>
  #	 <max33 coord="float"/>
  #    </matrix>
  #  </geo3D>	
  #</alignment>
  
  #The buildAlignment should be encoded by the SoureAdaptor subclasses
  for my $ali ($self->buildAlignment($query, $rows, $subjectsRefs, $subCoos)) {
    $response .= sprintf(qq(  <alignment name="%s" alignType="%s"%s%s>\n),
			 $ali->{'name'},
			 $ali->{'type'} || "unknown",
			 $ali->{'max'}      ?qq( max="$ali->{'max'}"):"",
			 $ali->{'position'} ?qq( position="$ali->{'position'}"):"");
    
    for my $aliObj (grep { $_ } @{$ali->{'alignObj'}}) {
      $response .= &genAlignObjectDasResponse($aliObj, "   ");
    }

    for my $score (@{$ali->{'scores'}}) {
      $response .= &genAlignScoreDasResponse($score, "   ");
    }

    for my $block (@{$ali->{'blocks'}}) {
      $response .= &genAlignBlockDasResponse($block, "   ");
    }

    for my $geo3D (@{$ali->{'geo3D'}}) {
      $response .= &genAlignGeo3dDasResponse($geo3D, "   ");
    }
    $response .= qq (  </alignment>\n);
  }

  return $response;
}

=head2 genAlignObjectDasResponse 

 Title    : genAlignObjectDasResponse
 Function : Formats the supplied alignment object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasalignment xml
 Args     : align data structure, spacing string
 Returns  : Das Response string encapuslating aliObject

=cut

sub genAlignObjectDasResponse {
  my ($aliObject, $spacing) = @_;
  my $response              = "";
  my $childElement          = 0;
  #Now get the attributes
  #print "|".Dumper($aliObject)."|\n";
  
  my $objVersion    = $aliObject->{'version'}   || "1.0";
  my $intObjectId   = $aliObject->{'intID'}     || "unknown";
  my $type          = $aliObject->{'type'};
  my $dbSource      = $aliObject->{'dbSource'}  || "unknown";
  my $dbVersion     = $aliObject->{'dbVersion'} || "unknown";
  my $dbCoordSys    = $aliObject->{'coos'};
  my $dbAccessionId = $aliObject->{'accession'} || "unknown";
  
  $response .= qq($spacing  <alignobject objVersion="$objVersion" intObjectId="$intObjectId" );
  $response .= qq(type="$type" ) if($type);
  $response .= qq(dbSource="$dbSource" dbVersion="$dbVersion" dbAccessionId="$dbAccessionId" );
  $response .= qq(dbCoodSys="$dbCoordSys" ) if($dbCoordSys);
  $response .= qq(>);

  for my $aliObjDetail (@{$aliObject->{'aliObjectDetail'}}) {
    $childElement++;
    my $detailDbSource = $aliObjDetail->{'source'}   || "unknown";
    my $property       = $aliObjDetail->{'property'} || "unknown";
    my $detail         = $aliObjDetail->{'detail'}   || "";
    $response         .= qq($spacing    <alignobjectdetail dbSource="$detailDbSource" property="$property");

    if($detail ne "") {
      $response .= qq(>$detail</alignobjectdetail>\n);

    } else {
      $response .= qq(/>\n);
    }
  }

  #Finally if the sequence is present, add this
  if(my $seq = $aliObject->{'sequence'}) {
    $childElement++;
    $response .= qq($spacing    <sequence>$seq</sequence>);
  }
  
  #Finish offthe ALIGNOBLECT
  if($childElement) {
    $response .= qq($spacing  </alignobject>);

  } else {
     #bit of a hack, but makes nice well formed xml
    chop($response);# This will remove the >
    $response .= qq(/>);
  }
  return $response;
}

=head2 genAlignScoreDasResponse

 Title   : genAlignScoreDasResponse
 Function: The takes an input score data structure and arbitrary spacing 
         : for pretty printing and converts the data structure into 
         : dasalignment xml
 Args    : score data structure, spacing string
 Returns : Das Response string from alignment score

=cut

sub genAlignScoreDasResponse {
  my($score, $spacing) = @_;
  my $methodName  = $score->{'method'} || "unknown";
  my $methodScore = $score->{'score'} || "0";
  return qq($spacing <score methodName="$methodName" value="$methodScore" />\n);
}


=head2 genAlignBlockDasResponse

 Title   : genAlignBlockDasResponse
 Function: The takes an input block data structure and arbitrary spacing 
         : for pretty printing and converts the block data structure into 
         : dasalignment xml
 Args    : block data structure, spacing string
 Returns : Das Response string from alignmentblock

=cut


sub genAlignBlockDasResponse {
  my($block, $spacing) = @_;
  my $response   = "";
  my $blockScore = $block->{'blockScore'} || "";# This is not required
  my $blockOrder = $block->{'blockOrder'} || 1; # This is required
  
  #The code assumes that if a block is passed in, it has an alignment
  #segment.  Although the code would not break, I doubt that it would validate
  #against the schema.

  #Block tag with required and optional attributes
  $response .= qq($spacing <block blockOrder="$blockOrder" );
  $response .= qq(blockScore="$blockScore") if($blockScore ne "");
  $response .= qq(>\n);
  
  #get segment data structures and convert these into das response xml
  for my $segment (@{$block->{'segments'}}) {
    my $objectId = $segment->{'objectId'}    || "unknown"; # required
    my $start    = $segment->{'start'}       || ""; # optional
    my $end      = $segment->{'end'}         || ""; # optional
    my $ori      = $segment->{'orientation'} || ""; #optional
    my $cigar    = $segment->{'cigar'}       || ""; #optional

    #Segment taq with required and then optional attributes added
    $response .= qq($spacing  <segment intObjectId="$objectId" );
    $response .= qq(start="$start" end="$end" ) if(($start ne "") and ($end ne "")); #Makes no sense to me to set one of these and not the other.
    $response .= qq(orientation="$ori") if($ori ne ""); # Genomic stuff

    if($cigar eq "") {
      $response .= qq(/>\n); #close the tag directly

    } else {
      #print the cigar string in tags and close the segment.
      $response .= qq(>\n$spacing   <cigar>"$cigar"</cigar>\n$spacing  </segment>\n);
    }
  }
  
  #close the block
  $response .= qq($spacing </block>\n);
  return $response;
}


=head2 genAlignGeo3dDasResponse

  Title    : genAlignGeo3d
  Function : Takes a geo3d data structure and arbitrary spacing for pretty printing and convertis it into DAS repsonse XML that represents the alignment matrix.
  Args     : data structure containing the vector and matrix, spacing string
  Returns  : String containing the DAS response xml

=cut

sub genAlignGeo3dDasResponse {
  my($geo3d, $spacing) = @_;
  #The geo3d is a reference to a 2D array.
  my $response    = "";
  my $intObjectId = $geo3d->{'intObjectId'} || "unknown";
  my $vector      = $geo3d->{'vector'};
  my $matrix      = $geo3d->{'matrix'};
  
  $response .= qq($spacing <geo3d intObjectId="$intObjectId">\n);

  if($vector && $matrix){ #These are bot required
    my $x      = $vector->{'x'} || "0.0";
    my $y      = $vector->{'y'} || "0.0";
    my $z      = $vector->{'z'} || "0.0";
    $response .= qq($spacing  <vector x="$x" y="$y" z="$z" />\n);
    $response .= qq($spacing  <matrix>\n);

    for my $m1 (0,1,2) {
      for my $m2 (0,1,2) {
	my $coordinate = $matrix->[$m1]->[$m2] || "0.0";
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


=head2 das_structure 

 Title    : das_structure
 Function : This produces the das repsonse for a pdb structure
 Args     : query options.  Currently, this will that query, chain and modelnumber.
          : The only part of the specification that this does not adhere to is the range argument. 
          : However, I think this argument is a potential can of worms!
 returns  : string containing Das repsonse for the pdb structure
 comment  : See http://www.efamily.org.uk/xml/das/documentation/structure.shtml for more information 
          : on the das structure specification.

=cut

sub das_structure {
  my($self, $opts) = @_;
  my $response     = "";
    
  #This is the sort of response that we should be producing.

  # <object dbAccessionId="1A4A" intObjectId="1A4A" objectVersion="29-APR-98" type="protein structure" dbSource="PDB" dbVersion="20040621" dbCoordSys="PDBresnum"/>
# -
# 	<chain id="A" SwissprotId="null">
# 
# 	<group name="ALA" type="amino" groupID="1">
# <atom atomID="1" atomName=" N  " x="-19.031" y="16.695" z="3.708"/>
# <atom atomID="2" atomName=" CA " x="-20.282" y="16.902" z="4.404"/>
# <atom atomID="3" atomName=" C  " x="-20.575" y="18.394" z="4.215"/>
# <atom atomID="4" atomName=" O  " x="-20.436" y="19.194" z="5.133"/>
# <atom atomID="5" atomName=" CB " x="-20.077" y="16.548" z="5.883"/>
# <atom atomID="6" atomName="1H  " x="-18.381" y="17.406" z="4.081"/>
# <atom atomID="7" atomName="2H  " x="-18.579" y="15.781" z="3.874"/>
# <atom atomID="8" atomName="3H  " x="-19.018" y="16.844" z="2.68"/>
# </group>

# <group name="HOH" type="hetatm" groupID="219">
# <atom atomID="3057" atomName=" O  " x="-17.904" y="13.635" z="-7.538"/>
# <atom atomID="3058" atomName="1H  " x="-18.717" y="14.098" z="-7.782"/>
# <atom atomID="3059" atomName="2H  " x="-17.429" y="13.729" z="-8.371"/>
# </group>
# </chain>
#
# <connect atomSerial="26" type="bond">
# <atomID atomID="25"/>
# <atomID atomID="242"/>
# </connect>

  #Get the arguments
  my $query     = $opts->{'query'};
  my $chainsRef = $opts->{'chains'} || undef;
  my $modelNo   = $opts->{'model'}  || undef;
    
  #The buildStructure should be specified by the sourceAdaptor subclass
  my $dasStructure = $self->buildStructure($query, $chainsRef, $modelNo);
    
  for my $obj (@{$dasStructure->{'objects'}}) {
    $response .= &genObjectDasResponse($obj, " ");
  }
    
    
  for my $chain (@{$dasStructure->{'chains'}}) {
    $response .= &genChainDasResponse($chain, " ");
  }
    
  for my $connect (@{$dasStructure->{'connects'}}) {
    $response .= &genConnectDasResponse($connect, " ");
  }

  return $response;    
}

=head2 genObjectDasResponse 

 Title    : genObjectDasResponse
 Function : Formats the supplied structure object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : object data structure, spacing string
 Returns  : Das Response string encapuslating "object"
 Comment  : The object response allows the details of the coordinates to be descriped. For example
          : the fact that the coos are part of a pdb file.

=cut

sub genObjectDasResponse {
  my ($object, $spacing) = @_;
  my $response      = "";
  my $childElement  = 0;

  my $objVersion    = $object->{'dbVersion'} || "1.0";
  my $type          = $object->{'type'};
  my $dbSource      = $object->{'dbSource'} || "unknown";
  my $dbVersion     = $object->{'dbVersion'} || "unknown";
  my $dbCoordSys    = $object->{'dbCoordSys'} || "pdb";
  my $dbAccessionId = $object->{'dbAccessionId'} || "unknown";
  $response .= qq($spacing <object objectVersion="$objVersion");
  $response .= qq( type="$type" ) if($type);
  $response .= qq( dbSource="$dbSource" dbVersion="$dbVersion" dbAccessionId="$dbAccessionId");
  $response .= qq( dbCoodSys="$dbCoordSys") if($dbCoordSys);
  $response .= qq(>);
    
  for my $objDetail (@{$object->{'objectDetails'}}){
    $childElement++;
    my $detailDbSource = $objDetail->{'source'} || "unknown";
    my $property       = $objDetail->{'property'} || "unknown";
    my $detail         = $objDetail->{'detail'} || "";
    $response         .= qq($spacing   <objectdetail dbSource="$detailDbSource" property="$property");

    if($detail ne "") {
      $response .= qq(>$detail</objectdetail>\n);
 
    } else {
      $response .= qq(/>\n);
    }	
  }
        
  #Finish off the object
  if($childElement) {
    $response .= qq($spacing  </object>);

  } else {
    #bit of a hack, but makes nice well formed xml
    chop($response);# This will remove the >
    $response .= qq(/>);
  }
  return $response;
}

=head2 genChainDasResponse 

 Title    : genChainDasResponse
 Function : Formats the supplied chain object data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : chain data structure, spacing string
 Returns  : Das Response string encapuslating "chain"
 Comment  : Chain objects contain all of the atom positions (including hetatoms).
          : The groups are typically residues or ligands.

=cut

sub genChainDasResponse {
  my ($chain, $spacing) = @_;
  my $response = "";
    

  #Set up the chain properties, chain id, swisprot mapping and model number.
  my $id      = $chain->{'id'} || "";
  $id         = "" if($id =~ /null/);
  my $modelNo = $chain->{'modelNumber'} || "";
  my $swissId = $chain->{'SwissprotId'} || undef;
    
  $response .= qq($spacing <chain id="$id");
  $response .= qq( model="$modelNo") unless($modelNo eq "");
  $response .= qq( SwissprotId="$swissId") unless (!$swissId);
  $response .= qq(\n>);
    
  #Now add the "residues" to the chain
  for my $group (@{$chain->{'groups'}}) {
    #Residue properties
    my $name    = $group->{'name'}; 
    my $type    = $group->{'type'};
    my $groupId = $group->{'id'};
    my $iCode   = $group->{'icode'} || undef;
	
    #Build the response
    $response .= qq($spacing   <group type="$type" groupID="$groupId" groupName="$name");
    $response .= qq( insertCode="$iCode") unless (!$iCode);
    $response .= qq(>);
	
    #Add the atoms to the chain
    for my $atom (@{$group->{'atoms'}}){
      #Atom properties
      my $atomId     = $atom->{'atomId'};
      my $atomName   = $atom->{'atomName'};
      my $x          = $atom->{'x'};
      my $y          = $atom->{'y'};
      my $z          = $atom->{'z'};
      my $occupancy  = $atom->{'occupancy'}  || undef;
      my $tempFactor = $atom->{'tempFactor'} || undef;
      my $altLoc     = $atom->{'altLoc'}     || undef;

      #Atom response
      $response .= qq($spacing    <atom  x="$x" y="$y" z="$z" atomName="$atomName" atomID="$atomId");
      $response .= qq( occupancy="$occupancy") unless(!$occupancy);
      $response .= qq( tempFactor="$tempFactor") unless(!$tempFactor);
      $response .= qq( altLoc="$altLoc") unless(!$altLoc);
      $response .= qq(/>);
    }
    #close group tag
    $response .= qq($spacing   </group>); 
  }

  #close chain tag
  $response .= qq($spacing </chain>);
  return $response;
}

=head2 genConnectDasResponse 

 Title    : genConnectDasResponse
 Function : Formats the supplied connect data structure and
          : arbitrary spacing for pretty printing and converts the
          : data structure into dasstructure xml
 Args     : connect data structure, spacing string
 Returns  : Das Response string encapuslating "connect"
 Comment  : Such objects are specified to enable groups of atoms to be connected together.   

=cut

sub genConnectDasResponse {
  my ($connect, $spacing) = @_;
  my $response    = "";
  my $atomSerial  = $connect->{'atomSerial'} || undef;
  my $connectType = $connect->{'type'}       || "unknown";

  if($atomSerial) {
    $response .= qq($spacing <connect atomSerial="$atomSerial" type="$connectType">\n);

    for my $atom (@{$connect->{'atom_ids'}}) {
      $response .= qq($spacing   <atomid atomID="$atom"/>\n);
    }
    $response .= qq($spacing </connect>);
  }
  return $response;
} 
1;
