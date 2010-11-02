#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: $Date: 2010-02-02 17:51:25 +0000 (Tue, 02 Feb 2010) $ $Author: andyjenkinson $
# Id:            $Id: SourceAdaptor.pm 637 2010-02-02 17:51:25Z andyjenkinson $
# Source:        $Source: /nfs/team117/rmp/tmp/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor.pm,v $
# $HeadURL: https://proserver.svn.sourceforge.net/svnroot/proserver/tags/spec-1.53/lib/Bio/Das/ProServer/SourceAdaptor.pm $
#
# Generic SourceAdaptor. Generates XML and manages callouts for DAS functions
#
package Bio::Das::ProServer::SourceAdaptor;
use strict;
use warnings;
use HTML::Entities qw(encode_entities_numeric);
use HTTP::Date qw(str2time time2isoz);
use English qw(-no_match_vars);
use Carp;
use File::Spec;

our $VERSION  = do { my ($v) = (q$Revision: 637 $ =~ /\d+/mxg); $v; };

sub new {
  my ($class, $defs) = @_;
  my $self = {
              'dsn'               => $defs->{'dsn'},
              'port'              => $defs->{'port'},
              'hostname'          => $defs->{'hostname'},
              'baseuri'           => $defs->{'baseuri'},
              'protocol'          => $defs->{'protocol'},
              'config'            => $defs->{'config'},
              'debug'             => $defs->{'debug'}    || undef,
              '_data'             => {},
              '_sequence'         => {},
              '_features'         => {},
             };

  bless $self, $class;
  $self->init($defs);

  if(!exists($self->capabilities->{'stylesheet'}) &&
     ($self->{'config'}->{'stylesheet'} ||
      $self->{'config'}->{'stylesheetfile'})) {
    $self->capabilities->{'stylesheet'} = '1.0';
  }

  # If not specified, we can check to see if a DAS source will support unknown segment errors
  if ( !(exists $self->capabilities->{'error-segment'} ||
         exists $self->capabilities->{'unknown-segment'}) &&
        ($self->known_segments()) ) {

    if ($self->implements('dna') || $self->implements('sequence')) {
      $self->capabilities->{'error-segment'} = '1.0';

    } else {
      $self->capabilities->{'unknown-segment'} = '1.0';
    }
  }

  if (exists $self->config->{'example_segment'}) {
    carp q(Warning: the 'example_segment' INI property is deprecated. Please use 'coordinates' instead.);
  }

  return $self;
}

sub init {return;}

sub length { return 0; } ## no critic (Subroutines::ProhibitBuiltinHomonyms)

sub source_uri {
  my $self = shift;
  return $self->{'source_uri'} || $self->config->{'source_uri'} || $self->version_uri;
}

sub version_uri {
  my $self = shift;
  return $self->{'version_uri'} || $self->config->{'version_uri'} || $self->dsn;
}

sub title {
  my $self = shift;
  return $self->{'title'} || $self->config->{'title'} || $self->dsn;
}

sub maintainer {
  my $self = shift;
  return $self->{'maintainer'} || $self->config->{'maintainer'} || q();
}

sub mapmaster {
  my $self = shift;
  return $self->{'mapmaster'} || $self->config->{'mapmaster'};
}

sub description {
  my $self = shift;
  return $self->{'description'} || $self->config->{'description'} || $self->title;
}

sub doc_href {
  my $self = shift;
  return $self->{'doc_href'} || $self->config->{'doc_href'};
}

sub strict_boundaries {
  my $self = shift;
  return $self->{'strict_boundaries'} || $self->config->{'strict_boundaries'};
}

sub known_segments {return;}

sub segment_version {return;}

sub init_segments {return;}

sub dsn {
  my $self = shift;
  return $self->{'dsn'} || 'unknown';
};

sub dsnversion {
  my $self = shift;
  return $self->{dsnversion} || $self->config->{dsnversion} || '1.0';
}

sub dsncreated {
  my $self = shift;
  my $datetime = $self->{dsncreated} || $self->config->{dsncreated};

  if (!$datetime) {
    if (defined $self->hydra && $self->hydra->can('last_modified')) {
      $datetime = $self->hydra->last_modified;
    } elsif (defined $self->transport && $self->transport->can('last_modified')) {
      $datetime = $self->transport->last_modified;
    }
  }

  return $datetime || 0; # epoch
}

sub _parse_config_hash {
    my $str  = shift;
    if ( defined $str ) {
        my @pairs = split qr(\s*[;\|]\s*)mx, $str;
        if ( @pairs ) {
            return { map { split qr(\s*[=-]>\s*)mx, $_, 2 } @pairs}; ## no critic
        }
    }
    return {};
}

sub coordinates {
  my $self = shift;

  if (!exists $self->{'coordinates'}) {
    $self->{'coordinates'} = _parse_config_hash( $self->config->{'coordinates'} );
  }

  return $self->{'coordinates'};
}

sub coordinates_full {
  my $self = shift;
  my @coords = ();
  while (my ($key, $test_range) = each %{ $self->coordinates() }) {
    my $coord = $Bio::Das::ProServer::COORDINATES->{lc $key};
    if (!$coord) {
      print {*STDERR} $self->dsn . " has unknown coordinate system: $key\n" or croak $ERRNO;
      next;
    }
    my %coord = %{ $coord };
    $coord{'test_range'} = $test_range;
    push @coords, \%coord;
  }
  return wantarray ? @coords : \@coords;
}


sub capabilities {
  my $self = shift;

  if (!exists $self->{'capabilities'}) {
    $self->{'capabilities'} = _parse_config_hash( $self->config->{'capabilities'} );
  }

  return $self->{'capabilities'};
}

sub properties {
  my $self = shift;

  if (!exists $self->{'properties'}) {
    $self->{'properties'} = _parse_config_hash( $self->config->{'properties'} );
  }

  return $self->{'properties'};
}

sub start { return 1; }

sub end {
  my ($self, @args) = @_;
  return $self->length(@args);
}

sub server_url {
  my $self = shift;
  my $host      = $self->{'hostname'};
  my $protocol  = $self->{'protocol'}  || 'http';
  my $port      = $self->{'port'}  || q();
  if ($port && ($protocol eq 'http' && $port ne '80') || ($protocol eq 'https' && $port ne '443') ) {
    $port = ":$port";
  } else {
    $port = q();
  }
  my $baseuri   = $self->{'baseuri'}   || q();
  return "$protocol://$host$port$baseuri";
}

sub source_url {
  my $self = shift;
  return $self->server_url().q(/das/).$self->dsn();
}

sub hydra {
  my $self = shift;
  return $self->config()->{'_hydra'};
}

sub transport {
  my ($self, $transport_name) = @_;
  $transport_name ||= q();
  my $config = $self->config;

  # Copy the config options, 'overwriting' with named-transport values where appropriate
  if ($transport_name) {
    my %config_copy = %{$config};
    while (my ($key, $val) = each %{$config}) {
      if ($key =~ s/^$transport_name\.//mx) {
        $config_copy{$key} = $val;
      }
    }
    $config = \%config_copy;
  }

  if(!exists $self->{'_transport'}{$transport_name} &&
     defined $config->{'transport'}) {
    my $transport = 'Bio::Das::ProServer::SourceAdaptor::Transport::'.$config->{'transport'};

    eval "require $transport" or carp $EVAL_ERROR; ## no critic(TestingAndDebugging::ProhibitNoStrict BuiltinFunctions::ProhibitStringyEval)
    eval {
      $self->{_transport}->{$transport_name} = $transport->new({
								dsn    => $self->{dsn}, # for debug purposes
								config => $config,
								debug  => $self->{debug},
							       });
    } or do {
      carp $EVAL_ERROR;
    };
  }
  return $self->{'_transport'}->{$transport_name};
}

sub config {
  my ($self, $config) = @_;
  if(defined $config) {
    $self->{config} = $config;
  }
  return $self->{config} || {};
}

sub implements {
  my ($self, $method) = @_;
  return $method?(exists $self->capabilities()->{$method}):undef;
}

# Ensures UNIX (seconds since epoch) format for 'dsncreated'
sub dsncreated_unix {
  my $self = shift;
  my $datetime = $self->dsncreated();
  if($datetime !~ m/^\d+$/mx) {
    $datetime = str2time($datetime);
  }
  return $datetime || 0; # if can't be parsed, use epoch
}

# Ensures ISO 8601 (yyyy-mm-ddThh::mm:ssZ) format for 'dsncreated'
sub dsncreated_iso {
  my $self     = shift;
  my $datetime = time2isoz($self->dsncreated_unix);
  $datetime    =~ s/\ /T/mx;
  return $datetime;
}

sub das_capabilities {
  my $self = shift;
  my $capabilities = $self->capabilities();
  return join q(; ), map {
    "$_/$capabilities->{$_}"
  } grep {
    defined $capabilities->{$_}
  } keys %{$capabilities};
}

sub authenticator {
  my ($self) = @_;
  my $config = $self->config;

  if (defined $config->{'authenticator'} && !exists $self->{'_auth'}) {
    $self->{'debug'} && carp "Building authenticator for $self->{'dsn'}";
    my $auth = 'Bio::Das::ProServer::Authenticator::'.$config->{'authenticator'};
    eval "require $auth" or do { }; ## no critic(BuiltinFunctions::ProhibitStringyEval)
    my $require_error = $EVAL_ERROR;
    eval {
      $self->{'_auth'} = $auth->new({
                                     'dsn'    => $self->{'dsn'}, # for debug purposes
                                     'config' => $config,
                                     'debug'  => $self->{'debug'},
                                    });
    } or do {
      # Require doesn't necessarily have to succeed, but if there was a problem loading the object it is fatal.
      if ($require_error && !$self->{'_auth'}) {
	croak $require_error;
      }
      croak $EVAL_ERROR;
    };
  }

  return $self->{'_auth'};
}

sub das_dsn {
  my $self = shift;

  my $mapmaster = $self->mapmaster();
  $mapmaster    = $mapmaster ? "<MAPMASTER>$mapmaster</MAPMASTER>" : q();
  my $content   = sprintf q(<DSN><SOURCE id="%s" version="%s">%s</SOURCE>%s<DESCRIPTION>%s</DESCRIPTION></DSN>),
                          $self->dsn(),
			  $self->dsnversion(),
			  $self->title(),
			  $mapmaster,
			  $self->description();

  return ($content);
}

sub unknown_segment {
  my ($self, $seg, $start, $end) = @_;

  if ($self->implements('dna') || $self->implements('sequence')) {
    return $self->error_segment($seg, $start, $end);
  }

  $start = $start ? qq( start="$start") : q();
  $end   = $end   ? qq( stop="$end")    : q();
  return qq(<UNKNOWNSEGMENT id="$seg"$start$end />);
}

sub error_segment {
  my ($self, $seg, $start, $end) = @_;
  $start = $start ? qq( start="$start") : q();
  $end   = $end   ? qq( stop="$end")    : q();
  return qq(<ERRORSEGMENT id="$seg"$start$end />);
}

#########
# code refactoring function to generate the link parts of the DAS response
#
sub _gen_link_das_response {
  my ($self, $link, $linktxt) = @_;
  my $response = q();

  #########
  # if $link is a reference to and array or hash use their contents as multiple links
  #
  if(ref $link eq 'ARRAY') {
    while(my $k = shift @{$link}) {
      my $v;
      if (ref $linktxt eq 'ARRAY') {
        $v = shift @{$linktxt};
      } elsif ($linktxt) {
        $v = $linktxt;
      }

      $response .= $v ? qq(<LINK href="$k">$v</LINK>)
                      : qq(<LINK href="$k" />);
    }

  } elsif(ref $link eq 'HASH') {
    for my $k (sort { $link->{$a} cmp $link->{$b} } keys %{$link}) {
      $response .= $link->{$k} ? qq(<LINK href="$k">$link->{$k}</LINK>)
                               : qq(<LINK href="$k" />);
    }

  } elsif($link) {
    $response .= $linktxt ? qq(<LINK href="$link">$linktxt</LINK>)
                          : qq(<LINK href="$link" />);
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
    my $encoded = {};
    while(my ($k, $v) = each %{$datum}) {
      if(defined $k) {
        encode_entities_numeric($k);
      }
      if(ref $v) {
	$self->_encode($v);
      } elsif(defined $v) {
	encode_entities_numeric($v);
      }
      $encoded->{$k} = $v;
    }
    %{$datum} = %{$encoded};

  } elsif(ref $datum eq 'ARRAY') {
    @{$datum} = map { (ref $_)?$self->_encode($_):defined$_?encode_entities_numeric($_):$_; } @{$datum};

  } elsif(ref $datum eq 'SCALAR') {
    if(defined ${$datum}) {
      ${$datum} = encode_entities_numeric(${$datum});
    }
  }

  return $datum;
}

#########
# code refactoring function to generate the feature parts of the DAS response
#
sub _gen_feature_das_response {
  my ($self, $feature) = @_;
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
  my $score     = $feature->{'score'};
  my $ori       = $feature->{'ori'};
  my $phase     = $feature->{'phase'};
  my $link      = $feature->{'link'}         || q();
  my $linktxt   = $feature->{'linktxt'}      || q();
  my $target    = $feature->{'target'};
  my $cat       = defined $feature->{'typecategory'}   ? qq( category="$feature->{'typecategory'}")     : defined $feature->{'type_category'}   ? qq( category="$feature->{'type_category'}")     : q();
  my $subparts  = defined $feature->{'typesubparts'}   ? qq( subparts="$feature->{'typesubparts'}")     : defined $feature->{'typessubparts'}   ? qq( subparts="$feature->{'typessubparts'}")     : q();
  my $supparts  = defined $feature->{'typesuperparts'} ? qq( superparts="$feature->{'typesuperparts'}") : defined $feature->{'typessuperparts'} ? qq( superparts="$feature->{'typessuperparts'}") : q();
  my $ref       = defined $feature->{'typereference'}  ? qq( reference="$feature->{'typereference'}")   : defined $feature->{'typesreference'}  ? qq( superparts="$feature->{'typesreference'}")  : q();
  $response    .= qq(<FEATURE id="$id" label="$label">);
  $response    .= qq(<TYPE id="$type"$cat$ref$subparts$supparts>$typetxt</TYPE>);
  $response    .= qq(<START>$start</START>);
  $response    .= qq(<END>$end</END>);
  $method and $response .= qq(<METHOD id="$method">$method_l</METHOD>);
  (defined $score)  and $response .= qq(<SCORE>$score</SCORE>);
  (defined $phase)  and $response .= qq(<PHASE>$phase</PHASE>);
  (defined $ori)    and $response .= qq(<ORIENTATION>$ori</ORIENTATION>);

  #########
  # Allow the 'note' tag to point to an array of notes.
  #
  if(ref $note eq 'ARRAY' ) {
    for my $n (grep { $note } @{$note}) {
      $response .= qq(<NOTE>$n</NOTE>);
    }

  } elsif($note) {
    $response .= qq(<NOTE>$note</NOTE>)
  }

  #########
  # Target can be an array of hashes
  #
  if($target && (ref $target eq 'ARRAY')) {
    for my $t (@{$target}) {
      $response .= sprintf q(<TARGET%s%s%s>%s</TARGET>),
			   $t->{'id'}    ?qq( id="$t->{'id'}")       :q(),
			   $t->{'start'} ?qq( start="$t->{'start'}") :q(),
			   $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :q(),
			   $t->{'targettxt'} || $t->{'target'} || sprintf q(%s:%d,%d), $t->{'id'}, $t->{'start'}, $t->{'stop'};
    }

  } elsif($feature->{'target_id'}) {
    $response .= sprintf q(<TARGET%s%s%s>%s</TARGET>),
			 $feature->{'target_id'}    ?qq( id="$feature->{'target_id'}")       :q(),
			 $feature->{'target_start'} ?qq( start="$feature->{'target_start'}") :q(),
			 $feature->{'target_stop'}  ?qq( stop="$feature->{'target_stop'}")   :q(),
			 $feature->{'targettxt'} || $feature->{'target_id'} || $feature->{'target'} ||
			 sprintf q(%s:%d,%d),
                                 $feature->{'target_id'},
				 $feature->{'target_start'},
				 $feature->{'target_stop'};
  }

  $response .= $self->_gen_link_das_response($link, $linktxt);

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
      $response    .= sprintf q(<GROUP id="%s"%s%s),
			      $groupi,
			      $groupinfo->{'grouplabel'} ?qq( label="$groupinfo->{'grouplabel'}") :q(),
			      $groupinfo->{'grouptype'}  ?qq( type="$groupinfo->{'grouptype'}")   :q();

      if (!$gnotei && !$glinki) {
        $response .= q(/>);

      } else {
        my $glinktxti = $groupinfo->{'grouplinktxt'} || q();
        $response    .= q(>);

	# Allow the 'note' tag to point to an array of notes.
	if(ref $gnotei eq 'ARRAY') {
	  for my $n (@{$gnotei}) {
	    $n or next;
	    $response .= qq(<NOTE>$n</NOTE>);
	  }

	} elsif($gnotei) {
	  $response .= qq(<NOTE>$gnotei</NOTE>);
	}
        $response .= $self->_gen_link_das_response($glinki, $glinktxti);

	if(ref $gtargeti eq 'ARRAY') {
	  for my $t (@{$gtargeti}) {
	    $response .= sprintf q(<TARGET%s%s%s>%s</TARGET>),
				 $t->{'id'}    ?qq( id="$t->{'id'}")       :q(),
				 $t->{'start'} ?qq( start="$t->{'start'}") :q(),
				 $t->{'stop'}  ?qq( stop="$t->{'stop'}")   :q(),
				 $t->{'targettxt'} || $t->{'target'} || sprintf '%s:%d,%d', $t->{'id'}, $t->{'start'}, $t->{'stop'};
	  }
	}

        $response .= q(</GROUP>);
      }
    }
  }

  $response .= q(</FEATURE>);
  return $response;
}

sub das_features {
  my ($self, $opts) = @_;
  my $response      = q();
  $self->_encode($opts);
  $self->init_segments($opts->{'segments'});

  my $segver = { };

  #########
  # features on segments
  #
  for my $seg (@{$opts->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();
    $seg ||= q();

    #########
    # If the requested segment is known to be not available it is an unknown or error segment.
    #
    my @known_segments = $self->known_segments();
    if(@known_segments && !scalar grep { /^$seg$/mx } @known_segments) {
      $response .= $self->unknown_segment($seg);
      next;
    }

    # The bounds of the segment (if known).
    my $segstart        = $self->start($seg);
    my $segend          = $self->end($seg);
    #########
    # If the request is known to be out of range it is an error segment.
    #
    if($self->strict_boundaries()) {
      if ( ($start && $segstart && $start < $segstart) || ($end && $segend && $end > $segend ) ) {
        $response .= $self->error_segment($seg, $start, $end);
        next;
      }
    }
    
    my @features = $self->build_features({
                                          'segment' => $seg,
                                          'start'   => $start,
                                          'end'     => $end,
                                          'types'   => $opts->{'types'},   # array
                                          'maxbins' => $opts->{'maxbins'}, # scalar
                                         });

    if (!exists $segver->{$seg}) {
      $segver->{$seg} = (scalar @features ? $features[0]->{'segment_version'} : undef)
                     || $self->segment_version($seg) || q(1.0);
    }

    $response .= sprintf q(<SEGMENT id="%s" version="%s" start="%s" stop="%s">),
                         $seg,
                         $segver->{$seg},
                         # The actual sequence positions we are querying for:
                         $start || $segstart || q(),
                         $end   || $segend   || q();

    for my $feature (@features) {
      $response .= $self->_gen_feature_das_response($feature);
    }

    $response .= q(</SEGMENT>);
  }

  #########
  # features by specific id
  #
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
      if (!exists $segver->{$seg}) {
        $segver->{$seg} = $feature->{'segment_version'} || $self->segment_version($seg) || q(1.0);
      }

      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || q();
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}   || q();
      my $segver   = $segver->{$seg};
      $response   .= qq(<SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">);
      $response   .= $self->_gen_feature_das_response($feature);
      $response   .= q(</SEGMENT>);
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
    $self->build_features({'group_id' => $_, 'types' => $opts->{'types'}, 'maxbins' => $opts->{'maxbins'}})

  } @{$opts->{'groups'}}) {

    if($feature->{'segment'} ne $lastsegid) {
      my $seg      = $feature->{'segment'}         || q();
      my $segstart = $feature->{'segment_start'}   || $feature->{'start'} || q();
      my $segend   = $feature->{'segment_end'}     || $feature->{'end'}   || q();
      my $segver   = $feature->{'segment_version'} || q(1.0);
      if($lastsegid) {
        $response   .= q(</SEGMENT>);
      }
      $response   .= qq(<SEGMENT id="$seg" version="$segver" start="$segstart" stop="$segend">);

      $lastsegid = $feature->{'segment'};
    }
    $response .= $self->_gen_feature_das_response($feature);
  }

  if($lastsegid) {
    $response .= q(</SEGMENT>);
  }

  return $response;
}

sub error_feature {
  my ($self, $f) = @_;
  return qq(<SEGMENT id=""><UNKNOWNFEATURE id="$f" /></SEGMENT>);
}

sub das_dna {
  my ($self, $segref) = @_;
  $self->_encode($segref);

  my $response = q();
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();

    #########
    # If the requested segment is known to be not available it is an unknown or error segment.
    #
    my @known_segments = $self->known_segments();
    if(@known_segments && !scalar grep { /^$seg$/mx } @known_segments) {
      $response .= $self->unknown_segment($seg);
      next;
    }

    # The bounds of the segment (if known).
    my $segstart        = $self->start($seg);
    my $segend          = $self->end($seg);

    #########
    # If the request is known to be out of range it is an error segment.
    #
    if($self->strict_boundaries()) {
      if ( ($start && $segstart && $start < $segstart) || ($end && $segend && $end > $segend ) ) {
        $response .= $self->error_segment($seg, $start, $end);
        next;
      }
    }

    # The actual sequence positions we are querying for.
    my $actstart        = $start || $segstart || q();
    my $actend          = $end   || $segend   || q();
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    $self->_encode($sequence);
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || $self->segment_version($seg) || q(1.0);
    my $len            = CORE::length $seq;
    $actstart        ||= 1;
    $actend          ||= $len + ($actstart-1);
    $response         .= qq(  <SEQUENCE id="$seg" start="$actstart" stop="$actend" moltype="$moltype" version="$version">\n);
    $response         .= qq(  <DNA length="$len">\n$seq\n  </DNA>\n  </SEQUENCE>\n);
  }
  return $response;
}

sub das_sequence {
  my ($self, $segref) = @_;
  $self->_encode($segref);

  my $response = q();
  for my $seg (@{$segref->{'segments'}}) {
    my ($seg, $coords) = split /:/mx, $seg;
    my ($start, $end)  = split /,/mx, $coords || q();

    #########
    # If the requested segment is known to be not available it is an unknown or error segment.
    #
    my @known_segments = $self->known_segments();
    if(@known_segments && !scalar grep { /^$seg$/mx } @known_segments) {
      $response .= $self->unknown_segment($seg);
      next;
    }

    # The bounds of the segment (if known).
    my $segstart        = $self->start($seg);
    my $segend          = $self->end($seg);

    #########
    # If the request is known to be out of range it is an error segment.
    #
    if($self->strict_boundaries()) {
      if ( ($start && $segstart && $start < $segstart) || ($end && $segend && $end > $segend ) ) {
        $response .= $self->error_segment($seg, $start, $end);
        next;
      }
    }

    # The actual sequence positions we are querying for.
    my $actstart        = $start || $segstart || q();
    my $actend          = $end   || $segend   || q();
    my $sequence       = $self->sequence({
					  'segment' => $seg,
					  'start'   => $start,
					  'end'     => $end,
					 });
    $self->_encode($sequence);
    my $seq            = $sequence->{'seq'};
    my $moltype        = $sequence->{'moltype'};
    my $version        = $sequence->{'version'} || $self->segment_version($seg) || q(1.0);
    $actstart ||= 1;
    $actend   ||= CORE::length($seq) + ($actstart-1);
    $response         .= qq(  <SEQUENCE id="$seg" start="$actstart" stop="$actend" moltype="$moltype" version="$version">\n$seq\n  </SEQUENCE>\n);
  }
  return $response;
}

sub das_types {
  my ($self, $opts) = @_;
  $self->_encode($opts);
  my $response      = q();
  my $data          = {};

  if(!scalar @{$opts->{'segments'}}) {
    $data->{'anon'} = [];
    push @{$data->{'anon'}}, $self->build_types();

  } else {
    for my $seg (@{$opts->{'segments'}}) {
      my ($seg, $coords) = split /:/mx, $seg;
      my ($start, $end)  = split /,/mx, $coords || q();

      #########
      # If the requested segment is known to be not available it is an unknown or error segment.
      #
      my @known_segments = $self->known_segments();
      if(@known_segments && !scalar grep { /^$seg$/mx } @known_segments) {
        $response .= $self->unknown_segment($seg);
        next;
      }

      # The bounds of the segment (if known).
      my $segstart        = $self->start($seg);
      my $segend          = $self->end($seg);

      #########
      # If the request is known to be out of range it is an error segment.
      #
      if($self->strict_boundaries()) {
        if ( ($start && $segstart && $start < $segstart) || ($end && $segend && $end > $segend ) ) {
          $response .= $self->error_segment($seg, $start, $end);
          next;
        }
      }

      # The actual sequence positions we are querying for.
      my $actstart        = $start || $segstart || q();
      my $actend          = $end   || $segend   || q();
      push @{$data->{"$seg:$actstart,$actend"}}, $self->build_types({
				   'segment' => $seg,
				   'start'   => $start,
				   'end'     => $end,
				  });
    }
  }

  for my $key (keys %{$data}) {
    my ($seg, $coords) = split /:/mx, $key;
    my ($start, $end)  = split /,/mx, $coords || q();

    if ($seg ne 'anon') {
      my $version = $self->segment_version($seg) || '1.0';
      $response .= qq(<SEGMENT id="$seg" start="$start" stop="$end" version="$version">);

    } else {
      $response .= q(<SEGMENT version="1.0">);
    }

    for my $type (@{$data->{$key}}) {
      $self->_encode($type);
      my $cat = $type->{category} || $type->{typecategory} || $type->{type_category};
      $response .= sprintf q(<TYPE id="%s"%s%s%s%s%s%s>%s</TYPE>),
			   $type->{type}       || q(),
			   $type->{method}      ?qq( method="$type->{method}")           : q(),
			   $cat                 ?qq( category="$cat")                    : q(),
			   $type->{c_ontology}  ?qq( c_ontology="$type->{c_ontology}")   : q(),
			   $type->{evidence}    ?qq( evidence="$type->{evidence}")       : q(),
			   $type->{e_ontology}  ?qq( e_ontology="$type->{e_ontology}")   : q(),
			   $type->{description} ?qq( description="$type->{description}") : q(),
			   $type->{count}      || q();
    }
    $response .= q(</SEGMENT>);
  }

  return $response;
}

sub build_types {
  my ($self, $args) = @_;
  my $types = ();
  for my $feat ( $self->build_features($args) ) {
    my $cat = $feat->{'typecategory'} || $feat->{'type_category'};
    my $key = join '/', $feat->{'type'}, $cat, $feat->{'method'};
    $types->{$key} ||= {
      'type'     => $feat->{'type'},
      'category' => $cat,
      'method'   => $feat->{'method'},
      'count'    => 0,
    };
    $types->{$key}{'count'}++,
  }
  return values %{ $types };
}

sub das_entry_points {
  my $self    = shift;
  my $content = q();
  
  for my $ep ($self->build_entry_points()) {
    $self->_encode($ep);

    # Check to see if both the start and the end are defined as we don't want
    # one without the other. 
    if (!defined $ep->{'start'} || !defined $ep->{'stop'}){
      $ep->{'start'} = $ep->{'stop'} = undef;
    }

    # default to yes here as we're giving entrypoints (if 'no' is specified, omit the field for brevity)
    # NOTE THAT THIS IS THE REVERSE OF THE DAS SPEC
    my $subparts = $ep->{'subparts'} && $ep->{'subparts'} eq 'no' ? q() : q( subparts="yes");
    $content    .= sprintf q(<SEGMENT id="%s" size="%s" %s%s%s%s>%s</SEGMENT>),
                           $ep->{'segment'} || q{},
                           $ep->{'length'}  || q{},
                           $subparts,
                           $ep->{'start'}   ? qq( start="$ep->{'start'}")     : q{},
                           $ep->{'stop'}    ? qq( stop="$ep->{'stop'}")       : q{},
                           $ep->{'ori'}     ? qq( orientation="$ep->{'ori'}") : q{},
                           $ep->{'segment'} || q{};
  }

  return $content;
}

sub build_entry_points {
  my $self = shift;
  return map { { 'segment' => $_, 'length' => $self->length($_), 'subparts' => 'no' } } $self->known_segments();
}

sub das_stylesheet {
  my $self = shift;
  my $defaultfile = File::Spec->catfile( $self->config->{'styleshome'},
                                         $self->config->{'stylesheetfile'} );
  return $self->_plain_response('stylesheet', $defaultfile) || q(<?xml version="1.0" standalone="yes"?><!DOCTYPE DASSTYLE SYSTEM "http://www.biodas.org/dtd/dasstyle.dtd"><DASSTYLE><STYLESHEET version="1.0"><CATEGORY id="default"><TYPE id="default"><GLYPH><BOX><FGCOLOR>red</FGCOLOR><FONT>sanserif</FONT><BGCOLOR>black</BGCOLOR></BOX></GLYPH></TYPE></CATEGORY></STYLESHEET></DASSTYLE>);
}

sub das_homepage {
  my $self = shift;
  my $dsn  = $self->dsn() || q();
  my $mm   = $self->mapmaster();
  $mm      = $mm?qq(<a href="$mm">$mm</a>):'none configured';
  my @segs = values %{ $self->coordinates };
  my $seg  = @segs ? $segs[0] : $self->config->{'example_segment'}; # example_segment is deprecated but supported

  return $self->_plain_response('homepage') || qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
 <head>
  <title>ProServer: Source Information for $dsn</title>
<style type="text/css">
html,body{background:#ffc;font-family:helvetica,arial,sans-serif}
thead{background-color:#700;color:#fff}
thead th{margin:0;padding:2px}
a{color:#a00;}a:hover{color:#aaa}
</style>
 </head>
 <body>
  <h1>ProServer: Source Information for $dsn</h1>
  <dl>
   <dt>DSN</dt>
   <dd>$dsn</dd>
   <dt>Description</dt>
   <dd>@{[$self->description()]}</dd>
   <dt>Mapmaster</dt>
   <dd>$mm</dd>
   <dt>Capabilities</dt>
   <dd>@{[map { my ($c) = $_ =~ m|(\w+)|;
                if($seg && $c eq 'features') { $c = "$c?segment=$seg"; }
                   qq(<a href="$dsn/$c">$_</a>);
                } split /;/mx, $self->das_capabilities()]}</dd>
  </dl>
 </body>
</html>\n);
}

sub das_sourcedata {
  my ($self, $opts) = @_;

  #########
  # The metadata for each source is built from:
  # 1. the adaptor
  # 2. the adaptor config
  # 3. global config

  # Opening tag for this source implementation (version)
  my $resp = sprintf q[<VERSION uri="%s" created="%s">], $self->version_uri(), $self->dsncreated_iso();

  # Co-ordinate systems (key can be URI or description, value is test range)
  my $coords = $self->coordinates_full();
  for my $coord (@{$coords}) {
    my $taxid   = $coord->{taxid}   ? qq[ taxid="$coord->{taxid}"]     : q();
    my $version = $coord->{version} ? qq[ version="$coord->{version}"] : q();
    $resp .= sprintf q[<COORDINATES uri="%s" source="%s" authority="%s"%s%s test_range="%s">%s</COORDINATES>],
                     $coord->{uri},
		     $coord->{source},
		     $coord->{authority},
		     $taxid,
		     $version,
		     $coord->{test_range},
		     $coord->{description};
  }

  # Supported commands
  # Capabilities are of form 'features' => '1.0'
  my $caps = $self->capabilities() || {};
  while (my ($cap, $ver) = each %{$caps}) {
    my $type      = 'das'.(int $ver);
    my $query_uri = (exists $Bio::Das::ProServer::WRAPPERS->{$cap})? (sprintf q[ query_uri="%s/%s"], $self->source_url, $cap): q();
    $resp .= qq[<CAPABILITY type="$type:$cap"$query_uri />];
  }

  # Custom properties
  my $props = $self->properties() || {};
  while (my ($name, $value) = each %{$props}) {
    my @values = (ref $value && ref $value eq 'ARRAY')? @{$value} : ($value);
    for my $detail (@values) {
      $resp .= sprintf q[<PROP name="%s" value="%s" />], $name, $detail;
    }
  }

  $resp .= q(</VERSION>);

  #########
  # Full data for all versions of a source
  #
  if(!$opts->{'skip_open'}) {
    $resp = sprintf q[<SOURCE uri="%s" title="%s" doc_href="%s" description="%s"><MAINTAINER email="%s" />%s],
                    $self->source_uri(),
		    $self->title(),
		    $self->doc_href() || $self->source_url(),
		    $self->description(),
		    $self->maintainer(), $resp;
  }

  if(!$opts->{'skip_close'}) {
    $resp .= q[</SOURCE>];
  }

  return $resp;
}

sub das_xsl {
  my ($self, $opts) = @_;
  my $call = $opts->{call};

  if(!$call) {
    return q();
  }

  my ($type)      = $call =~ m/(.+)\.xsl$/mx;
  my $defaultfile = File::Spec->catfile($self->config()->{'styleshome'}, "xsl_$call");
  my $response    = $self->_plain_response($type.q(_xsl), $defaultfile);

  if(!$response) {
    carp qq(Unable to parse $type XSL from disk);
  }

  return $response;
}

sub _plain_response {
  my ($self, $cfghead, $default) = @_;
  if(!$cfghead) {
    return q();
  }

  if($self->config->{$cfghead}) {
    #########
    # Inline static
    #
    return $self->config->{$cfghead};

  } else {
    my $filedata = $self->{"${cfghead}file"};
    for my $filename ($self->config->{"${cfghead}file"}, $default) {
      #########
      # import static file
      #
      last if $filedata;
      if ($filename) {
        
        if ($self->{'debug'}) {
          carp "Trying to read file: $filename";
        }
        if (-e $filename) {
          my ($fn) = $filename =~ m{([a-z\d_\./\-]+)}mix;
          eval {
            open my $fh, q(<), $fn or croak "Opening $filename '$fn': $ERRNO";
            local $RS = undef;
            $filedata = <$fh>;
            close $fh or croak $ERRNO;
            1;
          } or do {
            carp $EVAL_ERROR;
          };
        } elsif ($self->{'debug'}) {
          carp "File does not exist: $filename";
        }
      }
    }

    #########
    # Cache unless configured not to do so
    #
    if(($self->config->{"cache${cfghead}file"}||'yes') eq 'yes') {
      $self->{"${cfghead}file"} ||= $filedata;
    }

    $filedata and return $filedata;
  }
  return;
}

sub das_alignment {
  my ($self, $opts) = @_;
  $self->_encode($opts);
  my $response      = q();
  my $query         = $opts->{'query'};
  my $subjects_refs = $opts->{'subjects'};
  my $sub_coos      = $opts->{'subcoos'} || q();
  my $rows          = $opts->{'rows'}    || q();

  #########
  # If the requested segment is known to be not available it is an unknown or error segment.
  #
  my @known_segments = $self->known_segments();
  if(scalar @known_segments &&
     !scalar grep { /^$query$/mx } @known_segments) {
    return $self->unknown_segment($query);
  }

  #########
  # The build_alignment should be encoded by the SoureAdaptor subclasses
  #
  for my $ali ($self->build_alignment($query, $rows, $subjects_refs, $sub_coos)) {
    $self->_encode($ali);
    $response .= sprintf q(<alignment name="%s" alignType="%s"%s%s>),
			 $ali->{'name'},
			 $ali->{'type'} || 'unknown',
			 $ali->{'max'}      ?qq( max="$ali->{'max'}"):q(),
			 $ali->{'position'} ?qq( position="$ali->{'position'}"):q();

    for my $ali_obj (grep { $_ } @{$ali->{'alignObj'}}) {
      $response .= _gen_align_object_response($ali_obj);
    }

    for my $score (@{$ali->{'scores'}}) {
      $response .= _gen_align_score_response($score);
    }

    for my $block (@{$ali->{'blocks'}}) {
      $response .= _gen_align_block_response($block);
    }

    for my $geo3d (@{$ali->{'geo3D'}}) {
      $response .= _gen_align_geo3d_response($geo3d);
    }
    $response .= q(</alignment>);
  }

  return $response;
}

sub _gen_align_object_response {
  my ($ali_obj) = @_;
  my $children  = 0;

  my $coos = $ali_obj->{'dbCoordSys'} || $ali_obj->{'coos'};
  my $response = sprintf q(<alignObject objectVersion="%s" intObjectId="%s" %s dbSource="%s" dbVersion="%s" dbAccessionId="%s" %s>),
			 $ali_obj->{'version'}   || '1.0',
			 $ali_obj->{'id'}        || $ali_obj->{'intID'}     || 'unknown',
			 $ali_obj->{'type'}?qq(type="$ali_obj->{'type'}"):q(),
			 $ali_obj->{'dbSource'}  || 'unknown',
			 $ali_obj->{'dbVersion'} || 'unknown',
			 $ali_obj->{'dbAccession'} || $ali_obj->{'accession'} || 'unknown',
			 $coos?qq(dbCoordSys="$coos"):q();

  for my $detail (@{$ali_obj->{'aliObjectDetail'}}) {
    $children++;
    my $value = $detail->{'value'} || $detail->{'detail'};
    $response .= sprintf q(<alignObjectDetail dbSource="%s" property="%s"%s>),
			 $detail->{'dbSource'} || $detail->{'source'}   || 'unknown',
			 $detail->{'property'} || 'unknown',
			 $value?qq(>$value</alignObjectDetail):q(/);

  }

  #Finally if the sequence is present, add this
  if(my $seq = $ali_obj->{'sequence'}) {
    $children++;
    $response .= qq(<sequence>$seq</sequence>);
  }

  #Finish off the ALIGNOBLECT
  if($children) {
    $response .= q(</alignObject>);

  } else {
     #bit of a hack, but makes nice well formed xml
    chop $response; # This will remove the >
    $response .= q(/>);
  }
  return $response;
}

sub _gen_align_score_response {
  my($score) = @_;
  return sprintf q(<score methodName="%s" value="%s"/>),
                 $score->{'method'} || 'unknown',
		 $score->{'score'}  || '0';
}

sub _gen_align_block_response {
  my($block) = @_;

  #########
  # The code assumes that if a block is passed in, it has an alignment
  # segment.  Although the code would not break, I doubt that it would validate
  # against the schema.
  #

  #########
  # Block tag with required and optional attributes
  #
  my $response .= sprintf q(<block blockOrder="%s" %s>),
		  $block->{'blockOrder'} || 1,
		  $block->{'blockScore'}?qq(blockScore="$block->{'blockScore'}"):q();

  for my $segment (@{$block->{'segments'}}) {
    $response .= sprintf q(<segment intObjectId="%s"%s%s%s%s),
			 $segment->{'id'} || $segment->{'objectId'},
			 (exists $segment->{'start'})?qq( start="$segment->{'start'}"):q(),
			 (exists $segment->{'end'})  ?qq( end="$segment->{'end'}"):q(),
			 $segment->{'orientation'}?qq( orientation="$segment->{'orientation'}"):q(),
			 $segment->{'cigar'}?qq(><cigar>$segment->{'cigar'}</cigar></segment>):q(/>);
  }

  #########
  # close the block
  #
  $response .= q(</block>);
  return $response;
}

sub _gen_align_geo3d_response {
  my($geo3d) = @_;

  #########
  # The geo3d is a reference to a 2D array.
  #
  my $response = q();
  my $id       = $geo3d->{'id'} || $geo3d->{'intObjectId'} || 'unknown';
  my $vector   = $geo3d->{'vector'};
  my $matrix   = $geo3d->{'matrix'};

  $response .= qq(<geo3D intObjectId="$id">);

  if($vector && $matrix) { #These are both required
    my $x      = $vector->{'x'} || '0.0';
    my $y      = $vector->{'y'} || '0.0';
    my $z      = $vector->{'z'} || '0.0';
    $response .= qq(<vector x="$x" y="$y" z="$z"/>);
    $response .= q(<matrix);

    for my $m1 (0,1,2) {
      for my $m2 (0,1,2) {
	my $coordinate = $matrix->[$m1]->[$m2] || '0.0';
	my $n1         = $m1 + 1;#Bit of a hack, but ensures data integrity between the array and xml with next to no effort.
	my $n2         = $m2 + 1;#ditto
	$response     .= qq( mat$n1$n2="$coordinate");
      }
    }
    $response .= q(/>);
  }
  $response .= q(</geo3D>);
  return $response;
}


sub das_structure {
  my($self, $opts) = @_;
  $self->_encode($opts);
  my $response     = q();

  #Get the arguments
  my $query  = $opts->{'query'};
  my $chains = $opts->{'chains'} || undef;
  my $model  = $opts->{'model'}  || undef;

  #########
  # If the requested segment is known to be not available it is an unknown or error segment.
  #
  my @known_segments = $self->known_segments();
  if(@known_segments && !scalar grep { /^$query$/mx } @known_segments) {
    return $self->unknown_segment($query);
  }

  #The build_structure should be specified by the sourceAdaptor subclass

  my $structure = $self->build_structure($query, $chains, $model);
  $self->_encode($structure);

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
  my ($object) = @_;
  my $children = 0;

  my $response .= sprintf q(<object objectVersion="%s"%sdbSource="%s" dbVersion="%s" dbAccessionId="%s" dbCoordSys="%s">),
			  $object->{'dbVersion'}     || '1.0',
			  $object->{'type'}?qq( type="$object->{'type'}" ):q(),
			  $object->{'dbSource'}      || 'unknown',
			  $object->{'dbVersion'}     || 'unknown',
			  $object->{'dbAccessionId'} || 'unknown',
			  $object->{'dbCoordSys'}    || 'pdb';

  for my $objDetail (@{$object->{'objectDetails'}}) {
    $children++;
    $response .= sprintf q(<objectDetail dbSource="%s" property="%s" %s>),
			 $objDetail->{'source'}   || 'unknown',
			 $objDetail->{'property'} || 'unknown',
			 $objDetail->{'detail'}?qq(>$objDetail->{'detail'}</objectDetail):q();

  }

  #########
  # Finish off the object
  #
  if($children) {
    $response .= q(</object>);

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
  my ($chain) = @_;

  #########
  # Set up the chain properties, chain id, swisprot mapping and model number.
  #
  my $id = $chain->{'id'} || q();
  if($id =~ /null/mx) {
    $id = q();
  }

  my $response .= sprintf q(<chain id="%s" %s %s>),
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
    $response .= sprintf q(<group type="%s" groupID="%s" name="%s" %s>),
			 $group->{'type'},
			 $group->{'id'},
			 $group->{'name'},
			 $group->{'icode'}?qq(insertCode="$group->{'icode'}"):q();

    #########
    # Add the atoms to the chain
    #
    for my $atom (@{$group->{'atoms'}}) {
      $response .= sprintf q(<atom x="%s" y="%s" z="%s" atomName="%s" atomID="%s" %s %s %s/>),
			   (map { $atom->{$_} } qw(x y z atomName atomId)),
			   (map { $atom->{$_}?qq($_="$atom->{$_}"):q() } qw(occupancy tempFactor altLoc));

    }
    #close group tag
    $response .= q(</group>);
  }

  #close chain tag
  $response .= q(</chain>);
  return $response;
}

sub _gen_connect_response {
  my ($connect)    = @_;
  my $response     = q();
  my $atom_serial  = $connect->{'atomSerial'} || undef;
  my $connect_type = $connect->{'type'}       || 'unknown';

  if($atom_serial) {
    $response .= qq(<connect atomSerial="$atom_serial" type="$connect_type">);

    for my $atom (@{$connect->{'atom_ids'}}) {
      $response .= qq(<atomid atomID="$atom"/>);
    }
    $response .= q(</connect>);
  }
  return $response;
}

sub das_interaction {
  my ($self, $opts) = @_;
  $self->_encode($opts);

  my $operation   = $opts->{'operation'} || 'intersection';
  my $interactors = $opts->{'interactors'};
  my $details = {};
  for (@{ $opts->{'details'} }) {
    my ($key, $val) = split /,/mx, $_;
    $key =~ s/^property://mx;
    if(defined $val) {
      $val =~ s/^value://mx;
    }
    $details->{$key} = $val;
  }

  my $struct = $self->build_interaction({
                                         interactors => $interactors,
                                         details     => $details,
                                         operation   => $operation,
                                        });
  $self->_encode($struct);

  my $response = q();
  for my $interactor (@{ $struct->{interactors} }) {
    $response .= _gen_interactor_response($interactor);
  }

  for my $interaction (@{ $struct->{interactions} }) {
    $response .= _gen_interaction_response($interaction);
  }

  return $response;

}

sub _gen_interactor_response {
  my ($interactor) = @_;

  my $response = sprintf q(<INTERACTOR intId="%s" shortLabel="%s" dbSource="%s" dbAccessionId="%s" dbCoordSys="%s"),
                         $interactor->{id}          || 'unknown',
                         $interactor->{label}       || $interactor->{name} || $interactor->{id} || 'unknown',
                         $interactor->{dbSource}    || 'unknown',
                         $interactor->{dbAccession} || $interactor->{id}   || 'unknown',
                         $interactor->{dbCoordSys}  || 'unknown';
  if($interactor->{dbSourceCvId}) {
    $response .= sprintf q( dbSourceCvId="%s"), $interactor->{dbSourceCvId};
  }
  if($interactor->{dbVersion}) {
    $response .= sprintf q( dbVersion="%s"), $interactor->{dbVersion};
  }
  $response .= (exists $interactor->{details} || exists $interactor->{sequence}) ? q(>) : q(/>);

  my $details = $interactor->{details} || [];
  if (ref $details eq 'HASH') {
    $details = [$details];
  }

  for my $detail (@{$details}) {
    $response .= _gen_interaction_detail_response($detail);
  }

  if (my $sequence = $interactor->{sequence}) {
    if (! ref $sequence) {
      $sequence = {sequence=>$sequence};
    }
    $response .= sprintf q(<SEQUENCE%s%s>%s</SEQUENCE>),
                         $sequence->{start} ? qq( start="$sequence->{start}") : q(),
                         $sequence->{end}   ? qq( end="$sequence->{end}")     : q(),
                         $sequence->{sequence};
  }

  if(exists $interactor->{details} || exists $interactor->{sequence}) {
    $response .= q(</INTERACTOR>);
  }

  return $response;
}

sub _gen_interaction_response {
  my ($interaction) = @_;

  my $response = sprintf q(<INTERACTION name="%s" dbSource="%s" dbAccessionId="%s"),
                         $interaction->{label}       || $interaction->{name}  || 'unknown',
                         $interaction->{dbSource}    || 'unknown',
                         $interaction->{dbAccession} || $interaction->{label} || $interaction->{name} || 'unknown';
  if($interaction->{dbSourceCvId}) {
    $response .= sprintf q( dbSourceCvId="%s"), $interaction->{dbSourceCvId};
  }
  if($interaction->{dbVersion}) {
    $response .= sprintf q( dbVersion="%s"), $interaction->{dbVersion};
  }
  $response .= q(>);

  my $details = $interaction->{details} || [];
  if (ref $details eq 'HASH') {
    $details = [$details];
  }

  for my $detail (@{$details}) {
    $response .= _gen_interaction_detail_response($detail);
  }

  for my $participant (@{ $interaction->{participants} }) {
    $response .= qq(<PARTICIPANT intId="$participant->{id}");
    $response .= exists $participant->{details} ? q(>) : q(/>);
    $details = $participant->{details} || [];

    if (ref $details eq 'HASH') {
      $details = [$details];
    }

    for my $detail (@{$details}) {
      $response .= _gen_interaction_detail_response($detail);
    }
    $response .= exists $participant->{details} ? q(</PARTICIPANT>) : q();
  }
  $response .= q(</INTERACTION>);
  return $response;
}

sub _gen_interaction_detail_response {
  my ($details) = @_;

  my $response = sprintf q(<DETAIL property="%s" value="%s"),
                         $details->{property} || $details->{key},
                         $details->{value}    || $details->{details};
  if($details->{propertyCvId}) {
    $response .= sprintf q( propertyCvId="%s"), $details->{propertyCvId};
  }
  if($details->{valueCvId}) {
    $response .= sprintf q( valueCvId="%s"), $details->{valueCvId};
  }

  if ($details->{start}) {
    $response .= q(>);
    $response .= sprintf q(<RANGE start="%s" end="%s"),
                         $details->{start},
                         $details->{end} || $details->{start};
    if($details->{startStatus}) {
      $response .= sprintf q( startStatus="%s"), $details->{startStatus};
    }
    if($details->{endStatus}) {
      $response .= sprintf q( endStatus="%s"), $details->{endStatus};
    }
    if($details->{startStatusCvId}) {
      $response .= sprintf q( startStatusCvId="%s"), $details->{startStatusCvId};
    }
    if($details->{endStatusCvId}) {
      $response .= sprintf q( endStatusCvId="%s"), $details->{endStatusCvId};
    }
    $response .= q(/></DETAIL>);
  } else {
    $response .= q(/>);
  }

  return $response;
}

sub das_volmap {
  my ($self, $opts) = @_;
  $self->_encode($opts);

  my $segment = $opts->{query} || q();
  #########
  # If the requested segment is known to be not available it is an unknown or error segment.
  #
  my @known_segments = $self->known_segments();
  if ( !$segment || (@known_segments && !scalar grep { /^$segment$/mx } @known_segments) ) {
    return $self->unknown_segment($segment);
  }

  my $volmap = $self->build_volmap($segment);
  $self->_encode($volmap);
  my $response = sprintf q(<VOLMAP id="%s" class="%s" type="%s" version="%s">),
                         $volmap->{id},
                         $volmap->{class},
                         $volmap->{type},
                         $volmap->{version};
  my $link    = $volmap->{link};
  my $linktxt = $volmap->{linktxt} || $link;

  if (ref $link && ref $link eq 'HASH') {
    my @tmp = keys %{ $link };
    $linktxt = $link->{$tmp[0]};
    $link    = $tmp[0];
  }

  $response .= qq(<LINK href="$link">$linktxt</LINK></VOLMAP>);

  my $notes = $volmap->{note} || [];
  if(!ref $notes) {
    $notes = [$notes];
  }

  for (@{$notes}) {
    $response .= sprintf q(<NOTE>%s</NOTE>), $_;
  }

  return $response;
}

sub cleanup {
  my $self  = shift;
  my $debug = $self->{debug};

  if(!$self->config->{autodisconnect}) {
    $debug and print {*STDERR} "${self}::cleanup retaining transports\n";
    return;

  } else {
    if(!$self->{_transport}) {
      $debug and print {*STDERR} "${self}::cleanup no transports loaded\n";
      return;
    }

    for my $name (keys %{$self->{_transport}}) {
      my $transport = $self->transport($name);
      if($self->config->{autodisconnect} eq 'yes') {
        eval {
          $transport->disconnect();
          $debug and print {*STDERR} qq(${self}::cleanup performed forced transport disconnect\n);
	  1;
        } or do {
	};

      } elsif($self->config->{autodisconnect} =~ /(\d+)/mx) {
        my $now = time;
        if($now - $transport->init_time() > $1) {
          eval {
            $transport->disconnect();
            $transport->init_time($now);
            $debug and print {*STDERR} qq(${self}::cleanup performed timed transport disconnect\n);
	    1;
          } or do {
	  };
        }
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

$Revision: 637 $

=head1 SYNOPSIS

A base class implementing stubs for all SourceAdaptors.

=head1 DESCRIPTION

SourceAdaptor.pm generates XML and manages callouts for DAS request
handling.

If you're extending ProServer, this class is probably what you need to
inherit. The build_* methods are probably the ones you need to
extend. build_features() in particular.

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>

Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 SUBROUTINES/METHODS

=head2 new - Constructor

  my $oSourceAdaptor = Bio::Das::ProServer::SourceAdaptor::<implementation>->new({
    'dsn'      => q(),
    'port'     => q(),
    'hostname' => q(),
    'protocol' => q(),
    'baseuri'  => q(),
    'config'   => q(),
    'debug'    => 1,
  });

  Generally this would only be invoked on a subclass

=head2 init - Post-construction initialisation, passed the first argument to new()

  $oSourceAdaptor->init();

=head2 length - Returns the segment-length given a segment

  my $sSegmentLength = $oSourceAdaptor->length('DYNA_CHICK');
  
  By default returns 0

=head2 mapmaster - Mapmaster for this source.

  my $sMapMaster = $oSourceAdaptor->mapmaster();
  
  By default returns configuration 'mapmaster' setting

=head2 description - Description for this source.

  my $sDescription = $oSourceAdaptor->description();
  
  By default returns configuration 'description' setting or $self->title

=head2 doc_href - Location of a homepage for this source.

  my $sDocHref = $oSourceAdaptor->doc_href();
  
  By default returns configuration 'doc_href' setting

=head2 title - Short title for this source.

  my $title = $oSourceAdaptor->title();
  
  By default returns configuration 'title' setting or $self->source_uri

=head2 source_uri - URI for all versions of a source.

  my $uriS = $oSourceAdaptor->source_uri();
  
  By default returns configuration 'source_uri' setting or $self->dsn

=head2 version_uri - URI for a specific version of a source.

  my $uriV = $oSourceAdaptor->version_uri();
  
  By default returns configuration 'version_uri' setting or $self->source_uri

=head2 maintainer - Contact email for this source.

  my $email = $oSourceAdaptor->maintainer();
  
  By default returns configuration 'maintainer' setting, server setting or an empty string

=head2 strict_boundaries - Whether to return error segments for out-of-range queries

  my $strict = $oSourceAdaptor->strict_boundaries(); # boolean
  
  By default returns configuration 'strict_boundaries' setting, server setting or nothing (false)

=head2 build_features - (subclasses only) Fetch feature data

This call is made by das_features(). It is passed one of:

 { 'segment'    => $, 'start' => $, 'end' => $, 'types' => [$,$,...], 'maxbins' => $ }

 { 'feature_id' => $ }

 { 'group_id'   => $, 'types' => [$,$,...], 'maxbins' => $ }

 and is expected to return an array of hash references, i.e.
 ( {},{}...{} )

Each hash returned represents a single feature and should contain a
subset of the following keys and types. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 segment                       => $               # segment ID (if not provided)
 id       || feature_id        => $               # feature ID
 label    || feature_label     => $               # feature text label
 start                         => $               # feature start position
 end                           => $               # feature end position
 ori                           => $               # feature strand
 phase                         => $               # feature phase
 type                          => $               # feature type ID
 typetxt                       => $               # feature type text label
 typecategory || type_category => $               # feature type category
 typesubparts                  => $               # feature has subparts
 typesuperparts                => $               # feature has superparts
 typereference                 => $               # feature is reference
 method                        => $               # annotation method ID
 method_label                  => $               # annotation method text label
 score                         => $               # annotation score
 note                          => $ or [$,$,$...] # feature text note
 ##########################################################################
 # For one or more links:
 link                          => $ or [$,$,$...] # feature link href
 linktxt                       => $ or [$,$,$...] # feature link label
 # For hash-based links:
 link                          => {
                                   $ => $,        # href => label
                                   ...
                                  }
 ###############################################################################
 # For a single target:
 target_id                     => $               # target ID
 target_start                  => $               # target start position
 target_stop                   => $               # target end position
 targettxt                     => $               # target text label
 # For multiple targets:
 target                        => scalar or [{
                                              id        => $,
                                              start     => $,
                                              stop      => $,
                                              targettxt => $,
                                             },{}...]
 ###############################################################################
 # For a single group:
 group_id                      => $               # feature group ID
 grouplabel                    => $               # feature group text label
 grouptype                     => $               # feature group type ID
 groupnote                     => $               # feature group text note
 grouplink                     => $               # feature group ID
 grouplinktxt                  => $               # feature group ID
 # For multiple groups:
 group                         => [{
                                    grouplabel   => $
                                    grouptype    => $
                                    groupnote    => $
                                    grouplink    => $
                                    grouplinktxt => $
                                    note         => $ or [$,$,$...]
                                    target       => [{
                                                      id        => $
                                                      start     => $
                                                      stop      => $
                                                      targettxt => $
                                                     }],
                                   }, {}...]

=head2 sequence - (Subclasses only) fetch sequence/DNA data

This call is made by das_sequence() or das_dna(). It is passed:

 { 'segment'    => $, 'start' => $, 'end' => $ }

It is expected to return a hash reference:

 {
  seq     => $,
  version => $, # can also be specified with the segment_version method
  moltype => $,
 }

For details of the data constraints refer to the specification on biodas.org.

=head2 build_types - (Subclasses only) fetch type data

This call is made by das_types(). If no specific segments are requested by the
client, it is passed no arguments. Otherwise it is passed:

 { 'segment'    => $, 'start' => $, 'end' => $ }

It is expected to return an array of hash references, i.e.
 ( {},{}...{} )

Each hash returned represents a single type and should contain a
subset of the following keys and values. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 type                                  => $ # required
 count                                 => $ # required
 category|typecategory|type_category   => $
 method                                => $
 c_ontology                            => $
 evidence                              => $
 e_ontology                            => $
 description                           => $

=head2 build_entry_points - (Subclasses only) fetch entry_points data

This call is made by das_entry_points(). It is not passed any args

and is expected to return an array of hash references, i.e.
 ( {},{}...{} )

Each hash returned represents a single entry_point and should contain a
subset of the following keys and values. For scalar types (i.e. numbers
and strings) refer to the specification on biodas.org.

 segment  => $
 length   => $
 subparts => $
 start    => $
 stop     => $
 ori      => $

=head2 build_alignment - (Subclasses only) fetch alignment data

This call is made by das_alignment(). It is passed these arguments:

 (
  $,        # query sequence
  $,        # number of rows
  [ $, $ ], # subjects
  $         # subject coordinate system
 )

It is expected to return an array of alignment hash references:

 (
  {
   name     => $,
   type     => $,
   max      => $,
   position => $,
   alignObj => [
                {
                 id              => $, # internal object ID
                 version         => $,
                 type            => $,
                 dbSource        => $,
                 dbVersion       => $,
                 dbAccession     => $,
                 dbCoordSys      => $,
                 sequence        => $,
                 aliObjectDetail => [
                                     {
                                      property => $,
                                      value    => $,
                                      dbSource => $,
                                     },
                                    ],
                },
               ],
   scores   => [
                {
                 method => $,
                 score  => $,
                },
               ],
   blocks   => [
                {
                 blockOrder => $,
                 blockScore => $,
                 segments   => [
                                {
                                 id          => $, # internal object ID
                                 start       => $,
                                 end         => $,
                                 orientation => $, # + / - / undef
                                 cigar       => $,
                                },
                               ],
               ],
   geo3D    => [
                {
                 id
                 vector => {
                            x => $,
                            y => $,
                            z => $,
                           },
                 matrix => [
                            [$,$,$], # mat11, mat12, mat13
                            [$,$,$], # mat21, mat22, mat23
                            [$,$,$], # mat31, mat32, mat33
                           ],
                },
               ],
  }
 )

=head2 build_interaction - (Subclasses only) fetch interaction data

This call is made by das_interaction(). It is passed this structure:

 # For request:
 # /interaction?interactor=$;interactor=$;detail=property:$;detail=property:$,value:$
 {
  interactors => [$, $, ..],
  details     => {
                  $ => undef, # property exists
                  $ => $,     # property has a certain value
                 },
 }

It is expected to return a hash reference of interactions and interactors where 
all the requested interactors are part of the interaction:

 {
  interactors => [
                  {
                   id            => $,
                   label || name => $,
                   dbSource      => $,
                   dbSourceCvId  => $, # controlled vocabulary ID
                   dbVersion     => $,
                   dbAccession   => $,
                   dbCoordSys    => $, # co-ordinate system
                   sequence      => $,
                   details       => [
                                     {
                                      property        => $,
                                      value           => $,
                                      propertyCvId    => $,
                                      valueCvId       => $,
                                      start           => $, 
                                      end             => $,
                                      startStatus     => $,
                                      endStatus       => $,
                                      startStatusCvId => $,
                                      endStatusCvId   => $,
                                     },
                                     ..
                                    ],
                  },
                  ..
                 ],
  interactions => [
                   {
                    label || name => $,
                    dbSource      => $,
                    dbSourceCvId  => $,
                    dbVersion     => $,
                    dbAccession   => $,
                    details       => [
                                      {
                                       property     => $,
                                       value        => $,
                                       propertyCvId => $,
                                       valueCvId    => $,
                                      },
                                      ..
                                     ],
                    participants  => [
                                      {
                                       id      => $,
                                       details => [
                                                   {
                                                    property        => $,
                                                    value           => $,
                                                    propertyCvId    => $,
                                                    valueCvId       => $,
                                                    start           => $,
                                                    end             => $,
                                                    startStatus     => $,
                                                    endStatus       => $,
                                                    startStatusCvId => $,
                                                    endStatusCvId   => $,
                                                   },
                                                   ..
                                                  ],
                                      },
                                      ..
                                     ],
                   },
                   ..
                  ],
 }

=head2 build_volmap - (Subclasses only) fetch volume map data

This call is made by das_volmap(). It is passed a single 'query' argument.

It is expected to return a hash reference for a single volume map:

 {
  id      => $,
  class   => $,
  type    => $,
  version => $,
  link    => $,                  # href for data
  linktxt => $,                  # text
  note    => $  OR  [ $, $, .. ]
 }

=head2 init_segments - hook for optimising results to be returned.

  By default - do nothing
  Not necessary for most circumstances, but useful for deciding on what sort
  of coordinate system you return the results if more than one type is available.

  $self->init_segments() is called inside das_features() before build_features().

=head2 known_segments - returns a list of valid segments that this adaptor knows about

  my @aSegmentNames = $oSourceAdaptor->known_segments();

=head2 segment_version - gives the version of a segment (MD5 under certain circumstances) given a segment name

  my $sVersion = $oSourceAdaptor->segment_version($sSegment);

=head2 dsn - get accessor for this sourceadaptor's dsn

  my $sDSN = $oSourceAdaptor->dsn();

=head2 dsnversion - get accessor for this sourceadaptor's dsn version

  my $sDSNVersion = $oSourceAdaptor->dsnversion();
  
  By default returns $self->{'dsnversion'}, configuration 'dsnversion' setting or '1.0'

=head2 dsncreated - get accessor for this sourceadaptor's update time (variable format)
  
  # e.g. '2007-09-20T15:26:23Z'      -- ISO 8601, Coordinated Universal Time
  # e.g. '2007-09-20T16:26:23+01:00' -- ISO 8601, British Summer Time
  # e.g. '2007-09-20 07:26:23 -08'   -- indicating Pacific Standard Time
  # e.g. 1190301983                  -- UNIX
  # e.g. '2007-09-20'
  my $sDSNCreated = $oSourceAdaptor->dsncreated(); 
  
  By default tries and returns the following:
    1. $self->{'dsncreated'}
    2. configuration 'dsncreated' setting
    3. adaptor's 'last_modified' method (if it exists)
    4. zero (epoch)

=head2 dsncreated_unix - this sourceadaptor's update time, in UNIX format

  # e.g. 1190301983
  my $sDSNCreated = $oSourceAdaptor->dsncreated_unix();

=head2 dsncreated_iso - this sourceadaptor's update time, in ISO 8601 format

  # e.g. '2007-09-20T15:26:23Z'
  my $sDSNCreated = $oSourceAdaptor->dsncreated_iso();

=head2 coordinates - Returns this sourceadaptor's supported coordinate systems

  my $hCoords = $oSourceAdaptor->coordinates();
  
  Hash contains a key-value pair for each coordinate system, the key being
  either the URI or description, and the value being a suitable test range.
  
  By default returns an empty hash reference

=head2 coordinates_full : Returns this sourceadaptor's supported coordinate systems

  my $aCoords = $oSourceAdaptor->coordinates();
  
  Returns the fully-annotated co-ordinates systems this adaptor supports, as an
  array or array reference (depending on context):
    [
     {
      'description' => 'NCBI_36,Chromosome,Homo sapiens',
      'uri'         => 'http://www.dasregistry.org/dasregistry/coordsys/CS_DS40',
      'taxid'       => '9606',
      'authority'   => 'NCBI',
      'source'      => 'Chromosome',
      'version'     => '36',
      'test_range'  => '1:11000000,12000000',
     },
     {
      ...
     },
    ]
  
  The co-ordinate system details are read in from disk by Bio::Das::ProServer.
  By default returns an empty array.

=head2 capabilities - Returns this sourceadaptor's supported commands

  my $hCapabilities = $oSourceAdaptor->capabilities();
  
  Hash contains a key-value pair for each command, the key being the command
  name, and the value being the implementation version.
  
  By default returns an empty hash.

=head2 properties - Returns custom properties for this sourceadaptor

  my $hProps = $oSourceAdaptor->properties();
  
  Hash contains key-scalar or key-array pairs for custom properties.
  
  By default returns an empty hash reference

=head2 start - get accessor for segment start given a segment

  my $sStart = $oSourceAdaptor->start('DYNA_CHICK');

  By default returns 1

=head2 end - get accessor for segment end given a segment

  my $sEnd = $oSourceAdaptor->end('DYNA_CHICK');
  
  By default returns $self->length

=head2 server_url - Get the URL for the server (not including the /das)

  my $sUrl = $oSourceAdaptor->server_url();

=head2 source_url - Get the full URL for the source

  my $sUrl = $oSourceAdaptor->source_url();

=head2 hydra - Get the relevant B::D::PS::SourceHydra::<...> configured for this adaptor, if there is one

  my $oHydra = $oSourceAdaptor->hydra();

=head2 transport - Build the relevant B::D::PS::SA::Transport::<...> configured for this adaptor

  my $oTransport = $oSourceAdaptor->transport();
  
  OR
  
  my $oTransport1 = $oSourceAdaptor->transport('foo');
  my $oTransport2 = $oSourceAdaptor->transport('bar');

=head2 authenticator : Build the B::D::PS::Authenticator::<...> configured for this adaptor

  my $oAuthenticator = $oSourceAdaptor->authenticator();

  Authenticators are built only if explicitly configured in the INI file, e.g.:
  [mysource]
  state         = on
  adaptor       = simple
  authenticator = ip
  
  See L<Bio::Das::ProServer::Authenticator> for more details.

=head2 config - get/set config settings for this adaptor

  $oSourceAdaptor->config($oConfig);

  my $oConfig = $oSourceAdaptor->config();

=head2 implements - helper to determine if an adaptor implements a request based on its capabilities

  my $bIsImplemented = $oSourceAdaptor->implements($sDASCall); # e.g. $sDASCall = 'sequence'

=head2 das_capabilities - DAS-response capabilities header support

  my $sHTTPHeader = $oSourceAdaptor->das_capabilities();

=head2 unknown_segment - DAS-response unknown/error segment error response

  my $sXMLResponse = $sa->unknown_segment();

  Reference sources (i.e. those implementing the 'dna' or 'sequence' command) will return an <ERRORSEGMENT> element.
  Annotation sources will return an <UNKNOWNSEGMENT> element.

=head2 error_segment - DAS-response error segment error response

  my $sXMLResponse = $sa->error_segment();

  Returns an <ERRORSEGMENT> element.

=head2 error_feature - DAS-response unknown feature error

  my $sXMLResponse = $sa->error_feature();

=head2 das_features - DAS-response for 'features' request

  my $sXMLResponse = $sa->das_features();

  See the build_features method for details of custom implementations.

=head2 das_dna - DAS-response for DNA request

  my $xml = $sa->das_dna();

  See the sequence method for details of custom implementations.

=head2 das_sequence - DAS-response for sequence request

  my $sXMLResponse = $sa->das_sequence();

  See the sequence method for details of custom implementations.

=head2 das_types - DAS-response for 'types' request

  my $sXMLResponse = $sa->das_types();

  See the build_types method for details of custom implementations.

=head2 das_entry_points - DAS-response for 'entry_points' request

  my $sXMLResponse = $sa->das_entry_points();

  See the build_entry_points method for details of custom implementations.

=head2 das_interaction - DAS-response for 'interaction' request

  my $sXMLResponse = $sa->das_interaction();

  See the build_interaction method for details of custom implementations.

=head2 das_volmap - DAS-response for 'volmap' request

  my $sXMLResponse = $sa->das_volmap();

  See the build_volmap method for details of custom implementations.

=head2 das_stylesheet - DAS-response for 'stylesheet' request

  my $sXMLResponse = $sa->das_stylesheet();

  By default will use (in order of preference):
    the "stylesheet" INI property (inline XML)
    the "stylesheetfile" INI property (XML file location)
    the "stylesheetfile" INI property, prepended with the "styleshome" property
    a default stylesheet

=head2 das_sourcedata - DAS-response for 'sources' request

  my $sXMLResponse = $sa->das_sourcedata();

  Provides information about the DAS source for use in the sources command,
  such as title, description, coordinates and capabilities.

=head2 das_homepage - DAS-response (non-standard) for 'homepage' or blank request

  my $sHTMLResponse = $sa->das_homepage();

  By default will use (in order of preference):
    the "homepage" INI property (inline HTML)
    the "homepagefile" INI property (HTML file location)
    a default homepage

=head2 das_dsn - DAS-response (non-standard) for 'dsn' request

  my $sXMLResponse = $sa->das_dsn();

=head2 das_xsl - DAS-response (non-standard) for 'xsl' request

  my $sXSLResponse = $sa->das_xsl();

=head2 das_alignment - DAS-response for 'alignment' request

  my $sXMLResponse = $sa->das_alignment();

  See the build_alignment method for details of custom implementations.

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
    <vector />
    <matrix mat11="float" mat12="float" mat13="float"
            mat21="float" mat22="float" mat23="float"
            mat31="float" mat32="float" mat33="float" />
  </geo3D>	
</alignment>

=head2 _gen_align_object_response

 Title    : _gen_align_object_response
 Function : Formats alignment object into dasalignment xml
 Args     : align data structure
 Returns  : Das Response string encapuslating aliObject

=head2 _gen_align_score_response

 Title   : _gen_align_score_response
 Function: Formats input score data structure into dasalignment xml
 Args    : score data structure
 Returns : Das Response string from alignment score

=head2 _gen_align_block_response

 Title   : _gen_align_block_response
 Function: Formats an input block data structure into 
         : dasalignment xml
 Args    : block data structure
 Returns : Das Response string from alignmentblock

=head2 _gen_align_geo3d_response

  Title    : genAlignGeo3d
  Function : Formats geo3d data structure into alignment matrix xml
  Args     : data structure containing the vector and matrix
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
 Function : Formats the supplied structure object data structure into dasstructure xml
 Args     : object data structure
 Returns  : Das Response string encapuslating 'object'
 Comment  : The object response allows the details of the coordinates to be descriped. For example
          : the fact that the coos are part of a pdb file.

=head2 _gen_chain_response

 Title    : _gen_chain_response
 Function : Formats the supplied chain object data structure into dasstructure xml
 Args     : chain data structure
 Returns  : Das Response string encapuslating 'chain'
 Comment  : Chain objects contain all of the atom positions (including hetatoms).
          : The groups are typically residues or ligands.

=head2 _gen_connect_response

 Title    : _gen_connect_response
 Function : Formats the supplied connect data structure into dasstructure xml
 Args     : connect data structure
 Returns  : Das Response string encapuslating "connect"
 Comment  : Such objects are specified to enable groups of atoms to be connected together.

=head2 cleanup : Post-request garbage collection

=head1 CONFIGURATION AND ENVIRONMENT

Used within Bio::Das::ProServer::Config, eg/proserver and of course all subclasses.

=head1 DIAGNOSTICS

set $self->{'debug'} = 1

=head1 DEPENDENCIES

=over

=item L<HTML::Entities>

=item L<HTTP::Date>

=item L<English>

=item L<Carp>

=back

=head1 INCOMPATIBILITIES

None reported

=head1 BUGS AND LIMITATIONS

None reported

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 The Sanger Institute

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
