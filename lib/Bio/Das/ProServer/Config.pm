#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-06-03
# Last Modified: 2005-11-22
# Id:            $Id: Config.pm,v 2.55 2007/05/11 22:38:22 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/Config.pm,v $
# $HeadURL$
#
# ProServer source/parser configuration
#
package Bio::Das::ProServer::Config;
use strict;
use warnings;
use Bio::Das::ProServer::SourceAdaptor;
use Bio::Das::ProServer::SourceHydra;
use Sys::Hostname;
use Config::IniFiles;
use English qw(-no_match_vars);
use Carp;

our $VERSION = do { my @r = (q$Revision: 2.55 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub new {
  my ($class, $self)      = @_;
  $self                 ||= {};

  my $inifile = $self->{'inifile'} || q();
  ($inifile)  = $inifile =~ m|([a-z\d_/\.\-]+)|mix;

  if($inifile && -f $inifile) {
    my $conf = Config::IniFiles->new(
				     -file => $inifile,
				    );
    #########
    # load general parameters
    #
    for my $f (qw(hostname
                  port
                  response_hostname
                  response_port
                  response_protocol
                  response_baseuri
                  interface
                  prefork
                  maxclients
                  pidfile
                  logfile
                  ensemblhome
                  oraclehome
                  bioperlhome
                  http_proxy
                  serverroot
                  logformat)) {
      if($conf->val('general', $f)) {
	$self->{$f} ||= $conf->val('general', $f);
      }
      printf {*STDERR} qq(%-20s => %s\n), $f, ($self->{$f}||q());
    }

    #########
    # build the adaptors substructure
    #
    for my $s ($conf->Sections()) {
      if ($s eq 'general') {
	next;
      }

      print {*STDERR} qq(Configuring Adaptor $s );
      for my $p ($conf->Parameters($s)) {
	my $v = $conf->val($s, $p);
	$v    =~ s/\%serverroot/$self->{'serverroot'}/smgx;
	$self->{'adaptors'}->{$s}->{$p} = $v;

	if($p eq 'state') {
	  print {*STDERR} $self->{'adaptors'}->{$s}->{$p}, "\n";
	}
      }
    }

  } else {
   $self->{'debug'} and carp q(No configuration file available. Specify one with -c);
  }

  #########
  # set defaults if unset
  #
  $self->{'maxclients'} ||= 10;
  $self->{'port'}       ||= 9000;
  $self->{'hostname'}   ||= hostname();

  bless $self,$class;
  return $self;
}

sub port {
  my $self = shift;
  ($self->{'port'}) = $self->{'port'} =~ /(\d+)/mx;
  return $self->{'port'}||q();
}

sub maxclients {
  my ($self, $val)        = @_;

  if(defined $val) {
    $self->{'maxclients'} = $val;
  }

  ($self->{'maxclients'}) = $self->{'maxclients'} =~ /(\d+)/mx;
  return $self->{'maxclients'};
}

sub pidfile {
  my $self = shift;
  ($self->{'pidfile'}) = ($self->{'pidfile'}||q()) =~ m|([a-z\d/\-_\.]+)|mix;
  return $self->{'pidfile'};
}

sub logfile {
  my $self = shift;
  ($self->{'logfile'}) = ($self->{'logfile'}||q()) =~ m|([a-z\d/\-_\.]+)|mix;
  return $self->{'logfile'};
}

sub logformat {
  my $self = shift;
  return $self->{'logformat'} || '%i %t %r %s';
}

sub host {
  my $self = shift;
  my $h    = $self->{'interface'} || q();

  if(!$h || $h eq q(*)) {
    # if interface=*, always override with hostname
    $h       = $self->{'hostname'};
  }

  ($self->{'hostname'}) = $h =~ m|([a-z\d/\-_\.]+)|mix;
  return $self->{'hostname'}||q();
}

sub response_hostname {
  my $self = shift;
  return $self->{'response_hostname'} || $self->host();
}

sub response_port {
  my $self = shift;
  return $self->{'response_port'} || $self->port();
}

sub response_protocol {
  my $self = shift;
  return $self->{'response_protocol'} || 'http';
}

sub response_baseuri {
  my $self = shift;
  return $self->{'response_baseuri'} || q();
}

sub interface {
  my $self = shift;
  $self->{'interface'} ||= q();

  if($self->{'interface'} eq q(*)) {
    return;
  }

  return $self->{'interface'};
}

sub adaptors {
  my $self     = shift;
  my @adaptors = ();

  for my $dsn (grep { ($self->{'adaptors'}->{$_}->{'state'} || 'off') eq 'on'; } keys %{$self->{'adaptors'}}) {
    if($self->{'adaptors'}->{$dsn}->{'hydra'} ||
       (substr $dsn, 0, 5) eq 'hydra') {
      #########
      # This can be very slow, but we can't cache the results in case new hydras are added
      #
      $self->{'debug'} and carp qq(Cloning sources for managed $dsn);
      for my $managed_source ($self->hydra($dsn)->sources()) {
	my $adaptor = $self->_hydra_adaptor($dsn, $managed_source);

	if($adaptor) {
	  push @adaptors, $adaptor;
	}
      }
      $self->{'debug'} and carp q(Cloning complete);

    } else {
      push @adaptors, $self->adaptor($dsn);
    }
  }
  return @adaptors;
}

sub adaptor {
  my ($self, $dsn) = @_;

  if($dsn &&
     exists $self->{'adaptors'}->{$dsn} &&
     $self->{'adaptors'}->{$dsn}->{'state'} &&
     $self->{'adaptors'}->{$dsn}->{'state'} eq 'on') {
    
    $self->{'debug'} and print {*STDERR} qq(Acquiring unmanaged adaptor for $dsn\n);

    #########
    # normal adaptor
    #
    if(!exists $self->{'adaptors'}->{$dsn}->{'obj'}) {
      my $adaptortype = q(Bio::Das::ProServer::SourceAdaptor::).$self->{'adaptors'}->{$dsn}->{'adaptor'};
      eval "require $adaptortype"; ## no critic
      if($EVAL_ERROR) {
	carp "Error requiring $adaptortype: $EVAL_ERROR";
	return;
      }

      eval {
	$self->{'adaptors'}->{$dsn}->{'obj'} = $adaptortype->new({
								  'dsn'      => $dsn,
								  'config'   => $self->{'adaptors'}->{$dsn},
								  'hostname' => $self->{'response_hostname'} || $self->{'hostname'},
								  'port'     => $self->{'response_port'}     || $self->{'port'},
								  'protocol' => $self->{'response_protocol'},
								  'baseuri'  => $self->{'response_baseuri'},
								  'debug'    => $self->{'debug'},
								 });
      };
    }

    return $self->{'adaptors'}->{$dsn}->{'obj'};

  } elsif($dsn &&
	  ((substr $dsn, 0, 5) eq 'hydra' ||
	   grep {
	     $dsn=~/^$_/mx &&
	     $self->{'adaptors'}->{$_}->{'hydra'}
	   } keys %{$self->{'adaptors'}})) {

    $self->{'debug'} and print {*STDERR} qq(Acquiring managed adaptor for $dsn\n);

    #########
    # hydra adaptor
    #
    return $self->hydra_adaptor($dsn);

  } else {
    $self->{'debug'} and print {*STDERR} qq(Acquiring generic adaptor for unknown dsn @{[$dsn||"undef"]}\n);
    #########
    # generic adaptor
    #
    $self->{'_genadaptor'} ||= Bio::Das::ProServer::SourceAdaptor->new({
									'hostname' => $self->{'response_hostname'} || $self->{'hostname'},
									'port'     => $self->{'response_port'}     || $self->{'port'},
									'config'   => $self,
									'debug'    => $self->{'debug'},
								       });
    return $self->{'_genadaptor'};
  }
}

sub knows {
  my ($self, $dsn) = @_;

  #########
  # test plain sources
  #
  return 1 if(exists $self->{'adaptors'}->{$dsn}     &&
	      $self->{'adaptors'}->{$dsn}->{'state'} &&
	      $self->{'adaptors'}->{$dsn}->{'state'} eq 'on');

  #########
  # test hydra sources (slower)
  #
  for my $hydraname (grep {
    $self->{'adaptors'}->{$_}->{'hydra'} ||
      (substr $_, 0, 5) eq 'hydra'
    } keys %{$self->{'adaptors'}}) {

    if(!($self->{'adaptors'}->{$hydraname}->{'state'} &&
	 $self->{'adaptors'}->{$hydraname}->{'state'} eq 'on')) {
      next;
    }

    my $hydra = $self->hydra($hydraname);
    $hydra or next;

    if(grep { $_ eq $dsn } $hydra->sources()) {
      return 1;
    }
  }

  return;
}

sub das_version {
  return q(DAS/1.50);
}

sub hydra_adaptor {
  my ($self, $dsn, $hydraname) = @_;

  #########
  # sourceadaptor given known hydra
  #
  if($hydraname) {
    return $self->_hydra_adaptor($hydraname, $dsn);
  }

  #########
  # sourceadaptor search
  #
  for my $hydraname (grep {
    $self->{'adaptors'}->{$_}->{'hydra'} ||
    (substr $_, 0, 5) eq 'hydra'
  } keys %{$self->{'adaptors'}}) {

    my $adaptor = $self->_hydra_adaptor($hydraname, $dsn);
    $adaptor or next;
    return $adaptor;
  }

  return;
}

#########
# build hydra-based SourceAdaptor given dsn and hydraname
#
sub _hydra_adaptor {
  my ($self, $hydraname, $dsn) = @_;

  if(!($self->{'adaptors'}->{$hydraname}->{'state'} &&
       $self->{'adaptors'}->{$hydraname}->{'state'} eq 'on')) {
    return;
  }

  my $config = $self->{'adaptors'}->{$hydraname};
  my $hydra  = $self->hydra($hydraname);

  if(!( grep { $_ eq $dsn } $hydra->sources())) {
    return;
  }

  my $adaptortype = q(Bio::Das::ProServer::SourceAdaptor::).$self->{'adaptors'}->{$hydraname}->{'adaptor'};
  eval "require $adaptortype"; ## no critic

  if($EVAL_ERROR) {
    carp "Error requiring $adaptortype: $EVAL_ERROR";
    return;
  }

  #########
  # build a source adaptor using the dsn from the hydra-managed source and the config for the hydra
  #
  $config->{'hydraname'} = $hydraname;
  return $adaptortype->new({
			    'dsn'      => $dsn,
			    'config'   => $config,
			    'hostname' => $self->{'hostname'},
			    'port'     => $self->{'port'},
			    'debug'    => $self->{'debug'},
			   });
}

sub hydra {
  my ($self, $hydraname) = @_;
  $hydraname ||= q();

  if($hydraname &&
     !$self->{'adaptors'}->{$hydraname}->{'_hydra'}) {

    my $hydraimpl = 'Bio::Das::ProServer::SourceHydra::'.$self->{'adaptors'}->{$hydraname}->{'hydra'};
    eval "require $hydraimpl"; ## no critic

    if($EVAL_ERROR) {
      carp "Error requiring $hydraimpl: $EVAL_ERROR";
      return;
    }
    print {*STDERR} qq(Loaded $hydraimpl for $hydraname\n);

    $self->{'adaptors'}->{$hydraname}->{'_hydra'}  ||= $hydraimpl->new({
									'dsn'    => $hydraname,
									'config' => $self->{'adaptors'}->{$hydraname},
									'debug'  => $self->{'debug'},
								       });
  }
  return $self->{'adaptors'}->{$hydraname}->{'_hydra'} || undef;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::Config - configuration parsing and hooks

=head1 VERSION

$Revision: 2.55 $

=head1 SYNOPSIS

=head1 DESCRIPTION

Configuration takes the following structure

[general]
interface         = *    # interface to bind to ('*' for all)
port              = 9000 # port to listen on
response_hostname =      # overriding hostname for responses
response_port     =      # overriding port for responses
response_protocol =      # overriding protocol (http/s) for responses
response_baseuri  =      # overriding base-uri for responses
maxclients        = 10
pidfile           = 
logfile           = 
ensemblhome       =      # path to ensembl libs (for sharing across sources)
oraclehome        =      # path to oracle libs  (for sharing across sources)
bioperlhome       =      # path to bioperl libs (for sharing across sources)
http_proxy        =      # proxy for sources requiring web access
serverroot        = 
logformat         = %i %t %r %s

# then many of these with directives specific to each source
[sourcename]
adaptor    = adaptorpackage
stylesheet = /path/to/stylesheet.xml
...

# e.g. for mysql:
dbhost = localhost
dbport = 3306
dbuser = proserverro
dbpass = password

=head1 SUBROUTINES/METHODS

=head2 new : Constructor

  my $oConfig = Bio::Das::ProServer::Config->new("/path/to/proserver.ini");

=head2 port : get accessor for configured port

  my $sPort = $oConfig->port();

=head2 maxclients : get/set accessor for configured maxclients

  my $sMaxClients = $oConfig->maxclients();

=head2 pidfile : get accessor for configured pidfile

  my $sPidFile = $oConfig->pidfile();

=head2 logfile : get accessor for configured logfile

  my $sLogFile = $oConfig->logfile();

=head2 logformat : get accessor for configured logformat

  my $sLogformat = $oConfig->logformat();

  Special variables:
  %i      Remote IP
  %h      Remote hostname
  %t      Local time (YYYY-MM-DDTHH:MM:SS)
  %r      Request URI
  %s      HTTP status code

=head2 host : get accessor for configured host

  my $sHost = $cfg->host();

  Examines 'interface' and 'hostname' settings in that order

=head2 response_hostname : get accessor for configured response_hostname

  Useful for setting the hostname in XML/HTML responses when behind a reverse-proxy.

  my $sResponse_Hostname = $cfg->response_hostname();

  Examines 'response_hostname', 'interface' and 'hostname' settings in that order

=head2 response_port : get accessor for configured response_port

  Useful for setting the port in XML/HTML responses when behind a reverse-proxy.

  my $sResponse_Port = $cfg->response_port();

  Examines 'response_port' and 'port' settings in that order

=head2 response_protocol : get accessor for configured response_protocol

  Useful for setting the protocol in XML/HTML responses when behind a reverse-proxy.

  my $sResponse_Protocol = $cfg->response_protocol();

=head2 response_baseuri : get accessor for configured response_baseuri

  Useful for setting the baseuri (i.e. preceeding /das) in XML/HTML responses when behind a reverse-proxy.

  my $sResponse_Baseuri = $cfg->response_baseuri();

=head2 interface : get accessor configured interface

  my $sInterface = $cfg->interface();

=head2 adaptors : Build all known Bio::Das::ProServer::SourceAdaptors (including those Hydra-based)

  my @aAdaptors = $oConfig->adaptors();

  Note this can be an expensive call if lots of sources or large hydra sets are configured.

=head2 adaptor : Build a SourceAdaptor given a dsn (may be a hydra-based adaptor)

  my $oSourceAdaptor = $oConfig->adaptor($sWantedDSN);

=head2 knows : Is a requested dsn known about?

  my $bDSNIsKnown = $oConfig->knows($sWantedDSN);

=head2 das_version : Server-supported das version

  my $sVersion = $oConfig->das_version();

  By default 'DAS/1.50';

=head2 hydra_adaptor : Build a hydra-based SourceAdaptor given dsn and optional hydraname

  my $oAdaptor = $oConfig->hydra_adaptor($sWantedDSN, $sHydraName); # fast

  my $oAdaptor = $oConfig->hydra_adaptor($sWantedDSN); # slow, performs a full scan of any configured hydras

=head2 hydra : Build SourceHydra for a given dsn/hydraname

  my $oHydra = $oConfig->hydra($sHydraName);

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.
