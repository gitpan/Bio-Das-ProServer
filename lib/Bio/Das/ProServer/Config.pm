#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-06-03
# Last Modified: 2005-11-22
#
# Pro source/parser configuration
#
package Bio::Das::ProServer::Config;
use strict;
use Bio::Das::ProServer::SourceAdaptor;
use Bio::Das::ProServer::SourceHydra;
use Sys::Hostname;
use Config::IniFiles;

our $VERSION  = do { my @r = (q$Revision: 2.01 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head2 new : Constructor

  my $oConfig = Bio::Das::ProServer::Config->new("/path/to/proserver.ini");

=cut
sub new {
  my ($class, $self)      = @_;
  $self                 ||= {};
  $self->{'maxclients'} ||= 10;
  $self->{'port'}       ||= 9000;
  $self->{'hostname'}   ||= &hostname();

  my $inifile = $self->{'inifile'};
  ($inifile)  = ($inifile||"") =~ m|([a-zA-Z0-9_/\.\-]+)|;

  if($inifile && -f $inifile) {
    my $conf = Config::IniFiles->new(
				     -file => $inifile,
				    );
    #########
    # load general parameters
    #
    for my $f (qw(hostname
		  interface
		  prefork
		  maxclients
		  pidfile
		  logfile
		  port
		  ensemblhome
		  oraclehome
		  bioperlhome
		  http_proxy
		  serverroot)) {
      $self->{$f} = $conf->val("general", $f) if($conf->val("general", $f));
      printf STDERR qq(**** %s => %s ****\n), $f, ($self->{$f}||"");
    }

    #########
    # build the adaptors substructure
    #
    for my $s ($conf->Sections()) {
      next if ($s eq "general");
      print STDERR qq(Configuring Adaptor $s );
      for my $p ($conf->Parameters($s)) {
	my $v = $conf->val($s, $p);
	$v    =~ s/\%serverroot/$self->{'serverroot'}/smg;
	$self->{'adaptors'}->{$s}->{$p} = $v;
	print STDERR $self->{'adaptors'}->{$s}->{$p}, "\n" if($p eq "state");
      }
    }
  } else {
   $self->{'debug'} and warn qq(No configuration file available. Specify one with -c);
  }

  bless $self,$class;
  return $self;
}

=head2 port : get accessor for configured port

  my $sPort = $oConfig->port();

=cut
sub port {
  my $self = shift;
  ($self->{'port'}) = $self->{'port'} =~ /([0-9]+)/;
  return $self->{'port'}||"";
}

=head2 maxclients : get/set accessor for configured maxclients

  my $sMaxClients = $oConfig->maxclients();

=cut
sub maxclients {
  my ($self, $val)        = @_;
  $self->{'maxclients'}   = $val if(defined $val);
  ($self->{'maxclients'}) = $self->{'maxclients'} =~ /([0-9]+)/;
  return $self->{'maxclients'};
}

=head2 pidfile : get accessor for configured pidfile

  my $sPidFile = $oConfig->pidfile();

=cut
sub pidfile {
  my $self = shift;
  ($self->{'pidfile'}) = ($self->{'pidfile'}||"") =~ /([a-zA-Z0-9\/\-_\.]+)/;
  return $self->{'pidfile'};
}

=head2 logfile : get accessor for configured logfile

  my $sLogFile = $oConfig->logfile();

=cut
sub logfile {
  my $self = shift;
  ($self->{'logfile'}) = ($self->{'logfile'}||"") =~ /([a-zA-Z0-9\/\-_\.]+)/;
  return $self->{'logfile'};
}

=head2 host : get accessor for configured host

  my $sHost = $cfg->host();

  Examines 'interface' and 'hostname' settings in that order

=cut
sub host {
  my $self = shift;
  my $h    = $self->{'interface'} || "";
  $h       = $self->{'hostname'} if(!$h || $h eq "*"); # if interface=*, always override with hostname
  ($self->{'hostname'}) = $h =~ /([a-zA-Z0-9\/\-_\.]+)/;
  return $self->{'hostname'}||"";
}

=head2 interface : get accessor configured interface

  my $sInterface = $cfg->interface();

=cut
sub interface {
  my $self = shift;
  return $self->{'interface'} || $self->{'hostname'} || undef;
}

=head2 adaptors : Build all known Bio::Das::ProServer::SourceAdaptors (including those Hydra-based)

  my @aAdaptors = $oConfig->adaptors();

  Note this can be an expensive call if lots of sources or large hydra sets are configured.

=cut
sub adaptors {
  my $self     = shift;
  my @adaptors = ();

  for my $dsn (grep { ($self->{'adaptors'}->{$_}->{'state'} || "off") eq "on"; } keys %{$self->{'adaptors'}}) {
    if($self->{'adaptors'}->{$dsn}->{'hydra'} || substr($dsn, 0, 5) eq "hydra") {
      #########
      # This can be very slow, but we can't cache the results in case new hydras are added
      #
      $self->{'debug'} and warn qq(Cloning sources for managed $dsn);
      for my $managed_source ($self->hydra($dsn)->sources()) {
	my $adaptor = $self->_hydra_adaptor($dsn, $managed_source);
	push @adaptors, $adaptor if($adaptor);
      }
      $self->{'debug'} and warn qq(Cloning complete);

    } else {
      push @adaptors, $self->adaptor($dsn);
    }
  }
  return @adaptors;
}

=head2 adaptor : Build a SourceAdaptor given a dsn (may be a hydra-based adaptor)

  my $oSourceAdaptor = $oConfig->adaptor($sWantedDSN);

=cut
sub adaptor {
  my ($self, $dsn) = @_;

  if($dsn && exists $self->{'adaptors'}->{$dsn} && $self->{'adaptors'}->{$dsn}->{'state'} && $self->{'adaptors'}->{$dsn}->{'state'} eq "on") {
    $self->{'debug'} and print STDERR qq(Acquiring unmanaged adaptor for $dsn\n);
    #########
    # normal adaptor
    #
    if(!exists $self->{'adaptors'}->{$dsn}->{'obj'}) {
      my $adaptortype = "Bio::Das::ProServer::SourceAdaptor::".$self->{'adaptors'}->{$dsn}->{'adaptor'};
      eval "require $adaptortype";
      if($@) {
	warn "Error requiring $adaptortype: $@";
	return;
      }

      eval {
	$self->{'adaptors'}->{$dsn}->{'obj'} = $adaptortype->new({
								  'dsn'      => $dsn,
								  'config'   => $self->{'adaptors'}->{$dsn},
								  'hostname' => $self->{'hostname'},
								  'port'     => $self->{'port'},
								  'debug'    => $self->{'debug'},
								 });
      };
    }

    return $self->{'adaptors'}->{$dsn}->{'obj'};

  } elsif($dsn && (substr($dsn, 0, 5) eq "hydra" || grep{$dsn=~/^$_/ && $self->{'adaptors'}->{$_}->{'hydra'}} keys %{$self->{'adaptors'}})) {
    $self->{'debug'} and print STDERR qq(Acquiring managed adaptor for $dsn\n);
    #########
    # hydra adaptor
    #
    return $self->hydra_adaptor($dsn);

  } else {
    $self->{'debug'} and print STDERR qq(Acquiring generic adaptor for unknown dsn @{[$dsn||"undef"]}\n);
    #########
    # generic adaptor
    #
    $self->{'_genadaptor'} ||= Bio::Das::ProServer::SourceAdaptor->new({
									'hostname' => $self->{'hostname'},
									'port'     => $self->{'port'},
									'config'   => $self,
									'debug'    => $self->{'debug'},
								       });
    return $self->{'_genadaptor'};
  }
}

=head2 knows : Is a requested dsn known about?

  my $bDSNIsKnown = $oConfig->knows($sWantedDSN);

=cut
sub knows {
  my ($self, $dsn) = @_;

  #########
  # test plain sources
  #
  return 1 if(exists $self->{'adaptors'}->{$dsn} && $self->{'adaptors'}->{$dsn}->{'state'} && $self->{'adaptors'}->{$dsn}->{'state'} eq "on");

  #########
  # test hydra sources (slower)
  #
  for my $hydraname (grep { $self->{'adaptors'}->{$_}->{'hydra'} || substr($_, 0, 5) eq "hydra" } keys %{$self->{'adaptors'}}) {
    next unless($self->{'adaptors'}->{$hydraname}->{'state'} && $self->{'adaptors'}->{$hydraname}->{'state'} eq "on");
    my $hydra = $self->hydra($hydraname);
    next unless($hydra);
    return 1 if(grep { $_ eq $dsn } $hydra->sources());
  }
  return undef;
}

=head2 das_version : Server-supported das version

  my $sVersion = $oConfig->das_version();

  By default 'DAS/1.50';

=cut
sub das_version {
  return "DAS/1.50";
}

=head2 hydra_adaptor : Build a hydra-based SourceAdaptor given dsn and optional hydraname

  my $oAdaptor = $oConfig->hydra_adaptor($sWantedDSN, $sHydraName); # fast

  my $oAdaptor = $oConfig->hydra_adaptor($sWantedDSN); # slow, performs a full scan of any configured hydras

=cut
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
  for my $hydraname (grep { $self->{'adaptors'}->{$_}->{'hydra'} || substr($_, 0, 5) eq "hydra" } keys %{$self->{'adaptors'}}) {
    my $adaptor = $self->_hydra_adaptor($hydraname, $dsn);
    $adaptor or next;
    return $adaptor;
  }
  return undef;
}

#########
# build hydra-based SourceAdaptor given dsn and hydraname
#
sub _hydra_adaptor {
  my ($self, $hydraname, $dsn) = @_;

  return unless($self->{'adaptors'}->{$hydraname}->{'state'} && $self->{'adaptors'}->{$hydraname}->{'state'} eq "on");
  my $config = $self->{'adaptors'}->{$hydraname};
  my $hydra  = $self->hydra($hydraname);

  return unless( grep { $_ eq $dsn } $hydra->sources());

  my $adaptortype = "Bio::Das::ProServer::SourceAdaptor::".$self->{'adaptors'}->{$hydraname}->{'adaptor'};
  eval "require $adaptortype";

  if($@) {
    warn "Error requiring $adaptortype: $@";
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

=head2 hydra : Build SourceHydra for a given dsn/hydraname

  my $oHydra = $oConfig->hydra($sHydraName);

=cut
sub hydra {
  my ($self, $hydraname) = @_;
  $hydraname ||= "";

  if($hydraname && !$self->{'adaptors'}->{$hydraname}->{'_hydra'}) {
    my $hydraimpl = "Bio::Das::ProServer::SourceHydra::".$self->{'adaptors'}->{$hydraname}->{'hydra'};
    eval "require $hydraimpl";
    if($@) {
      warn "Error requiring $hydraimpl: $@";
      return;
    }
    print STDERR qq(Loaded $hydraimpl for $hydraname\n);

    $self->{'adaptors'}->{$hydraname}->{'_hydra'}  ||= $hydraimpl->new({
									'dsn'    => $hydraname,
									'config' => $self->{'adaptors'}->{$hydraname},
									'debug'  => $self->{'debug'},
								       });
  }
  return $self->{'adaptors'}->{$hydraname}->{'_hydra'} || undef;
}

1;
