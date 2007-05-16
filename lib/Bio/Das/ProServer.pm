#!/usr/local/bin/perl
#########
# ProServer DAS Server
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2003-05-22
# Last Modified: $Date: 2007/03/09 14:21:23 $
# Source:        $Source $
# Id:            $Id $
#

package Bio::Das::ProServer;
use warnings;
use strict;
use Bio::Das::ProServer::Config;
use CGI qw(:cgi);
use Compress::Zlib;
use Getopt::Long;
use POE;                         # Base features.
use POE::Filter::HTTPD;          # For serving HTTP content.
use POE::Wheel::ReadWrite;       # For socket I/O.
use POE::Wheel::SocketFactory;   # For serving socket connections.
use POSIX qw(setsid strftime);
use Sys::Hostname;
use Bio::Das::ProServer::SourceAdaptor;
use Bio::Das::ProServer::SourceHydra;
use Socket;
use English qw(-no_match_vars);
use Carp;

our $DEBUG          = 0;
our $VERSION        = do { my @r = (q$Revision: 2.60 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };
our $GZIP_THRESHOLD = 10_000;
$ENV{'PATH'}        = '/bin:/usr/bin:/usr/local/bin';
our $WRAPPERS       = {
		       'dsn'          => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<?xml-stylesheet type="text/xsl" href="dsn.xsl"?>\n<!DOCTYPE DASDSN SYSTEM 'http://www.biodas.org/dtd/dasdsn.dtd' >\n<DASDSN>\n),
					  'close' => qq(</DASDSN>\n),
					 },
		       'features'     => {
					  'open'  => qq(<?xml version="1.0" standalone="yes"?>\n<?xml-stylesheet type="text/xsl" href="features.xsl"?>\n<!DOCTYPE DASGFF SYSTEM "http://www.biodas.org/dtd/dasgff.dtd">\n<DASGFF>\n  <GFF version="1.01" href="%protocol://%host:%port%baseuri/das/%dsn/features">\n),
					  'close' => qq(  </GFF>\n</DASGFF>\n),
					 },
		       'dna'          => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASDNA SYSTEM "http://www.biodas.org/dtd/dasdna.dtd">\n<DASDNA>\n),
					  'close' => qq(</DASDNA>\n),
					 },
		       'sequence'     => {
					  'open'  => qq(<!DOCTYPE DASSEQUENCE SYSTEM "http://www.biodas.org/dtd/dassequence.dtd">\n<DASSEQUENCE>\n),
					  'close' => qq(</DASSEQUENCE>\n),
					 },
		       'types'        => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASTYPES SYSTEM "http://www.biodas.org/dtd/dastypes.dtd">\n<DASTYPES>\n  <GFF version="1.0" href="%protocol://%host:%port%baseuri/das/%dsn/types">\n),
					  'close' => qq(  </GFF>\n</DASTYPES>\n),
					 },
		       'entry_points' => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASEP SYSTEM "http://www.biodas.org/dtd/dasep.dtd">\n<DASEP>\n  <ENTRY_POINTS href="%protocol://%host:%port%baseuri/das/%dsn/entry_points" version="1.0">\n),
					  'close' => qq(  </ENTRY_POINTS>\n</DASEP>\n),
					 },
		       'alignment'    => {
                                          'open'  => qq(<?xml version="1.0" standalone="no"?>\n<dasalignment xmlns="http://www.efamily.org.uk/xml/das/2004/06/17/dasalignment.xsd" xmlns:align="http://www.efamily.org.uk/xml/das/2004/06/17/alignment.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema-instance" xsd:schemaLocation="http://www.efamily.org.uk/xml/das/2004/06/17/dasalignment.xsd http://www.efamily.org.uk/xml/das/2004/06/17/dasalignment.xsd">\n),
                                          'close' => qq(</dasalignment>\n),
					},
                       'structure'    => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<dasstructure xmlns="http://www.efamily.org.uk/xml/das/2004/06/17/dasstructure.xsd" xmlns:xsd="http://www.w3.org/2001/XMLSchema-instance" xsd:schemaLocation="http://www.efamily.org.uk/xml/das/2004/06/17/dasstructure.xsd http://www.efamily.org.uk/xml/das/2004/06/17/dasstructure.xsd">\n),
                                          'close' => qq(</dasstructure>\n),
					 },
		      };

sub run {
  my $class       = shift;
  my $self        = bless {}, $class;
  my $opts        = {};
  $self->{'opts'} = $opts;
  my @saveargv    = @ARGV;
  my $result      = GetOptions(
                            $opts,
                            qw(debug
                               version
                               port=i
                               help|usage
                               hostname=s
                               inifile|config|c=s
                               X|x),
			   );
  $DEBUG   = $opts->{'debug'};
  my $vstr = "ProServer DAS Server v$VERSION (c) GRL 2007";

  if($opts->{'version'}) {
    print $vstr, "\n";
    return;
  }

  my @msg = ($vstr,
	     'http://www.sanger.ac.uk/proserver/', q(),
	     'Please cite:',
	     ' ProServer: A simple, extensible Perl DAS server.',
	     ' Finn RD, Stalker JW, Jackson DK, Kulesha E, Clements J, Pettett R.',
	     ' Bioinformatics 2007; doi: 10.1093/bioinformatics/btl650; PMID: 17237073',
	    );

  my $maxmsg = (sort { $b <=> $a } map { length $_ } @msg)[0];

  print  q(#)x($maxmsg+6), "\n";
  for my $m (@msg) {
    printf qq(#  %-${maxmsg}s  #\n), $m;
  }
  print  q(#)x($maxmsg+6), "\n\n";

  @ARGV = @saveargv;

  if($opts->{'help'}) {
    print qq(
 -debug           # Enable extra debugging
 -port   <9000>   # Listen on this port (overrides configuration file)
 -hostname <*>    # Listen on this interface x (overrides configuration file)
 -help            # This help
 -config          # Use this configuration file
 -x               # Development mode - disables server forking\n\n);
    return;
  }

  if(!$opts->{'inifile'}) {
    $opts->{'inifile'} = 'eg/proserver.ini';
    print {*STDERR} qq(Using default '$opts->{'inifile'}' file.\n);
  }

  if(!-e $opts->{'inifile'}) {
    print {*STDERR} qq(Invalid configuration file: $opts->{'inifile'}. Stopping.\n);
    return;
  }

  # backwards-compatibility switch
  $opts->{'interface'} = $opts->{'hostname'};
  delete $opts->{'hostname'};

  my $config = Bio::Das::ProServer::Config->new($opts);
  $self->{'config'} = $config;

  if(!$opts->{'X'} && fork) {
    print {*STDERR} qq(Parent process detached...\n);
    return;

  } elsif($opts->{'X'}) {
    $config->maxclients(0);
  }

  setsid() or croak 'Cannot setsid';

  my $logfile = $config->logfile();
  if (!defined $logfile) {
    my ($pidpath)  = ($config->pidfile()   ||q()) =~ m|^(.*)/|mx;
    my ($confpath) = ($config->{'inifile'} ||q()) =~ m|^(.*)/|mx;
    $pidpath     ||= $confpath;
    $pidpath      .= $pidpath?q(/):q();
    $logfile       = sprintf '%sproserver.%s.log', $pidpath, hostname();
  }

  open STDIN,  '<', '/dev/null' or croak "Can't open STDIN from /dev/null: [$!]\n";
  if(!$opts->{'X'}) {
    my $errlog = $logfile;
    $errlog    =~ s/\.log$/.err/mx;
    print {*STDERR} qq(Logging STDOUT to $logfile and STDERR to $errlog\n);
    open STDOUT, '>', $logfile  or croak "Can't open STDOUT to $logfile: [$!]\n";
    open STDERR, '>', $errlog   or croak "Can't open STDERR to STDOUT: [$!]\n";
  }

  if(exists $config->{'ensemblhome'}) {
    $ENV{'ENS_ROOT'}     = $config->{'ensemblhome'};
    print {*STDERR} qq(Set ENS_ROOT to $ENV{'ENS_ROOT'}\n);
  }

  if(exists $config->{'oraclehome'}) {
    $ENV{'ORACLE_HOME'}  = $config->{'oraclehome'};
    print {*STDERR} qq(Set ORACLE_HOME to $ENV{'ORACLE_HOME'}\n);
  }

  if(exists $config->{'bioperlhome'}) {
    $ENV{'BIOPERL_HOME'} = $config->{'bioperlhome'};
    print {*STDERR} qq(Set BIOPERL_HOME to $ENV{'BIOPERL_HOME'}\n);
  }

  my $pidfile = $config->pidfile() || sprintf '%s.%s.pid', $PROGRAM_NAME||'proserver', hostname() || 'localhost';
  $self->make_pidfile($pidfile);

  $self->{'logformat'} = $config->logformat();

  # Spawn up to max server processes, and then run them.  Exit
  # when they are done.

  $self->server_spawn($config->maxclients());
  $poe_kernel->run();
  return;
}

sub DEBUG         { return $DEBUG; } # Enable a lot of runtime information.
sub TESTING_CHURN { return 0; }                # Randomly shutdown children to test respawn.

### Spawn the main server.  This will run as the parent process.

sub server_spawn {
  my ($self, $max_processes) = @_;

  return POE::Session->create(
			      inline_states =>
			      { _start         => \&server_start,
				_stop          => \&server_stop,
				do_fork        => \&server_do_fork,
				got_error      => \&server_got_error,
				got_sig_hup    => \&server_got_sig_hup,
				got_sig_int    => \&server_got_sig_int,
				got_sig_chld   => \&server_got_sig_chld,
				got_connection => \&server_got_connection,
				
				_child => sub { 0 },
			      },
			      heap => {
				       max_processes => $max_processes,
				       self          => $self,
				      },
			     );
}

### The main server session has started.  Set up the server socket and
### bookkeeping information, then fork the initial child processes.

sub server_start {
  my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
  my $config = $heap->{'self'}->{'config'};

  $heap->{server} = POE::Wheel::SocketFactory->new
    ( BindAddress    => $config->interface()||undef,
      BindPort       => $config->port(),
      SuccessEvent   => 'got_connection',
      FailureEvent   => 'got_error',
      Reuse          => 'on',
      SocketDomain   => AF_INET,
      SocketType     => SOCK_STREAM,
      SocketProtocol => 'tcp',
      ListenQueue    => SOMAXCONN,
    );

  $kernel->sig( CHLD  => 'got_sig_chld' );
  $kernel->sig( INT   => 'got_sig_int' );
  $kernel->sig( TERM  => 'got_sig_int' );
  $kernel->sig( KILL  => 'got_sig_int' );
  $kernel->sig( HUP   => 'got_sig_hup' );
  $kernel->sig( USR1  => 'got_sig_hup' );

  $heap->{children}   = {};
  $heap->{is_a_child} = 0;

  carp sprintf qq(Server %d has begun listening on %s:%d\n),
    $PID,
    $config->interface(),
    $config->port();

  $kernel->yield('do_fork');
  carp 'Exited fork';
  return;
}

### The server session has shut down.  If this process has any
### children, signal them to shutdown too.

sub server_stop {
  my $heap = $_[HEAP];
  DEBUG and carp "Server $PID stopped.\n";
  if ( my @children = keys %{ $heap->{children} } ) {
    DEBUG and carp "Server $PID is signaling children to stop.\n";
    kill INT => @children;
  }
  return $heap->{'self'}->remove_pidfile();
}

### The server session has encountered an error.  Shut it down.

sub server_got_error {
  my ( $heap, $syscall, $errno, $error ) = @_[ HEAP, ARG0 .. ARG2 ];
  DEBUG and
    carp( "Server $PID got $syscall error $errno: $error\n",
	  "Server $PID is shutting down.\n",
	);
  delete $heap->{server};
  return;
}

### The server has a need to fork off more children.  Only honor that
### request form the parent, otherwise we would surely "forkbomb".
### Fork off as many child processes as we need.

sub server_do_fork {
  my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];

  return if $heap->{is_a_child};

  my $current_children = keys %{ $heap->{children} };
  for ( $current_children + 2 .. $heap->{max_processes} ) {

    DEBUG and carp "Server $PID is attempting to fork.\n";

    my $pid = fork;

    if(!defined $pid) {
      DEBUG and
	carp( "Server $PID fork failed: $!\n",
	      "Server $PID will retry fork shortly.\n",
	    );
      $kernel->delay( do_fork => 1 );
      return;
    }

    # Parent.  Add the child process to its list.
    if ($pid) {
      $heap->{children}->{$pid} = 1;
      next;
    }

    # Child.  Clear the child process list.
    DEBUG and carp "Server $PID forked successfully.\n";
    $heap->{is_a_child} = 1;
    $heap->{children}   = {};
    $heap->{hitcount}   = 0;
    return;
  }
  return;
}

### The server session received SIGHUP.  Re-execute this process, remembering any argv options

sub server_got_sig_hup {
  DEBUG and carp "Server $PID received SIGHUP|USR1.\n";

  #########
  # shutdown children
  #
  server_stop(@_);

  #########
  # exec(self)
  #
  print {*STDERR} qq(0=$PROGRAM_NAME, argv=@ARGV\n);
  return exec $PROGRAM_NAME, @ARGV;
}

### The server session received SIGINT.  Don't handle the signal,
### which in turn will trigger the process to exit gracefully.

sub server_got_sig_int {
  DEBUG and carp "Server $PID received SIGINT.\n";
  return 0;
}

### The server session received a SIGCHLD, indicating that some child
### server has gone away.  Remove the child's process ID from our
### list, and trigger more fork() calls to spawn new children.

sub server_got_sig_chld {
  my ( $kernel, $heap, $child_pid ) = @_[ KERNEL, HEAP, ARG1 ];

  if ( delete $heap->{children}->{$child_pid} ) {
    DEBUG and carp "Server $PID received SIGCHLD.\n";
    $kernel->yield('do_fork');
  }
  return 0;
}

### The server session received a connection request.  Spawn off a
### client handler session to parse the request and respond to it.

sub server_got_connection {
  my ( $heap, $socket, $peer_addr, $peer_port ) = @_[ HEAP, ARG0, ARG1, ARG2 ];

  DEBUG and carp "Server $PID received a connection.\n";

  POE::Session->create(
		       inline_states =>
		       { _start      => sub { eval { client_start(@_); }; carp $EVAL_ERROR if($EVAL_ERROR); },
			 _stop       => \&client_stop,
			 got_request => sub { eval { client_got_request(@_); }; carp $EVAL_ERROR if($EVAL_ERROR); },
			 got_flush   => \&client_flushed_request,
			 got_error   => \&client_got_error,
			 _parent     => sub { 0 },
		       },
		       heap =>
		       { self      => $heap->{'self'},
			 socket    => $socket,
			 peer_addr => $peer_addr,
			 peer_port => $peer_port,
		       },
		      );

  if(TESTING_CHURN and $heap->{is_a_child} and ( rand() < 0.1 )) {
    delete $heap->{server}
  }
  return;
}

### The client handler has started.  Wrap its socket in a ReadWrite
### wheel to begin interacting with it.

sub client_start {
  my $heap = $_[HEAP];

  $heap->{client} = POE::Wheel::ReadWrite->new(
					       Handle       => $heap->{socket},
					       Filter       => POE::Filter::HTTPD->new(),
					       InputEvent   => 'got_request',
					       ErrorEvent   => 'got_error',
					       FlushedEvent => 'got_flush',
					      );

  DEBUG and carp "Client handler $PID/", $_[SESSION]->ID, " started.\n";
  return;
}

### The client handler has stopped.  Log that fact.

sub client_stop {
  DEBUG and carp "Client handler $PID/", $_[SESSION]->ID, " stopped.\n";
  return;
}

### The client handler has received a request.  If it's an
### HTTP::Response object, it means some error has occurred while
### parsing the request.  Send that back and return immediately.
### Otherwise parse and process the request, generating and sending an
### HTTP::Response object in response.

sub client_got_request {
  my ( $heap, $request) = @_[ HEAP, ARG0 ];

  DEBUG and
    carp "Client handler $PID/", $_[SESSION]->ID, " is handling a request.\n";

  if ( $request->isa('HTTP::Response') ) {
    $heap->{client}->put($request);

  } else {
    my $response = build_das_response($heap, $request);
    $heap->{hitcount}++;
    $heap->{client}->put($response);
  }

  return;
}

sub build_das_response {
  my ($heap, $request) = @_;

  my $config = $heap->{'self'}->{'config'};

  #########
  # Handle DAS responses here
  #
  my $response     = HTTP::Response->new(200);
  my $uri          = $request->uri();
  my ($dsn, $call) = $uri =~ m|/das/([^/\?\#]+)(?:/([^/\?\#]+))?|mx;
  $dsn           ||= q();

  if($dsn && !$call) {
    $call = 'homepage';
  }

  if($dsn eq 'dsn.xsl') {
    $response->content_type('text/xml');
    $response->content(Bio::Das::ProServer::SourceAdaptor->new->das_xsl({'call'=>'dsn.xsl'}));

  } elsif($dsn && $config->knows($dsn)) {
    my $mimetype = ($call eq 'homepage')?'text/html':'text/xml';
    $response->content_type($mimetype);
    my $cgi;

    #########
    # process the parameters
    #
    if ($request->method() eq 'GET') {
      my ($query) = $request->uri() =~ /\?(.*)$/mx;
      $cgi = CGI->new($query);

    } elsif ($request->method() eq 'POST') {
      $cgi = CGI->new($request->{'_content'});
    }

    my $method   = "das_$call";
    my $segments = [$cgi->param('segment')];
    my $features = [$cgi->param('feature_id')];
    my $groups   = [$cgi->param('group_id')];
    my $query    = $cgi->param('query');
    my $chains   = [$cgi->param('chain')];
    my $ranges   = [$cgi->param('range')];
    my $model    = [$cgi->param('model')];
    my $subjects = [$cgi->param('subject')];
    my $rows     = $cgi->param('rows');
    my $subcoos  = $cgi->param('subjectcoordsys');
    my $adaptor  = $config->adaptor($dsn);
    if(substr($call, -3, 3) eq 'xsl') {
      $method = 'das_xsl';
    }

    if($adaptor->implements($call) ||
       $call   eq 'homepage'       ||
       $method eq 'das_xsl') {

      my $use_gzip = 0;
      if($call   ne 'homepage'               &&
         $method ne 'das_xsl' ){
        $adaptor->transport->can('last_modified') and $response->last_modified($adaptor->transport->last_modified);
	if( $request->header('Accept-Encoding') &&
	   ($request->header('Accept-Encoding') =~ /gzip/mx) ) {
	  DEBUG and carp 'Turning on compression';
	  $use_gzip = 1;
        }
      }

      eval {
	my $head     = $WRAPPERS->{$call}->{'open'}  || q();
	my $foot     = $WRAPPERS->{$call}->{'close'} || q();
	my $host     = $config->response_hostname();
	my $port     = $config->response_port()      || q();
	my $protocol = $config->response_protocol()  || 'http';
	my $baseuri  = $config->response_baseuri()   || q();
	$head        =~ s/\%protocol/$protocol/smgx;
	$head        =~ s/\%baseuri/$baseuri/smgx;
	$head        =~ s/\%host/$host/smgx;
	$head        =~ s/\%port/$port/smgx;
	$head        =~ s/\%dsn/$dsn/smgx;
	my $content  = $head.$adaptor->$method({
						'call'     => $call,
						'segments' => $segments,
						'features' => $features,
						'groups'   => $groups,
						'query'    => $query,
						'subjects' => $subjects,
						'chains'   => $chains,
						'ranges'   => $ranges,
						'model'    => $model,
						'rows'     => $rows,
						'subcoos'  => $subcoos,
					       }).$foot;

	if( ($use_gzip && (length($content) > $GZIP_THRESHOLD)) ) {
	  if(DEBUG) {
	    carp 'Compressing content';
	  }
	  my $squashed = Compress::Zlib::memGzip($content);

	  if($squashed) {
	    $content = $squashed;
	    $response->content_encoding('gzip');

	  } else {
	    carp "Content compression failed: $!\n";
	  }
	}

	$response->content_length(length $content);
	$response->content($content);
      };

      if($EVAL_ERROR) {
	carp $EVAL_ERROR;
	$response->content_type('text/plain');
	$response->code(501); #?
	$response->content('source error');
      }

    } else {
      $response->content_type('text/plain');
      $response->code(501);
      $response->content(qq(call @{[$call||q()]} unimplemented));
    }

    $adaptor->cleanup();

  } elsif($dsn eq 'dsn') {
    $response->content_type('text/xml');

    #########
    # Building this response here isn't particularly nice
    # but it saves the penalty of initialising another new sourceadaptor
    #
    $response->content_type('text/xml');
    my $dsnxml = qq(@{[map {
        my $mapmaster = $_->mapmaster() || $_->config->{'mapmaster'};
        $mapmaster    = $mapmaster?"    <MAPMASTER>$mapmaster</MAPMASTER>\n":q();
        sprintf qq(  <DSN>\n    <SOURCE id="%s" version="%s">%s</SOURCE>\n%s    <DESCRIPTION>%s</DESCRIPTION>\n  </DSN>\n),
                $_->dsn(),
                $_->dsnversion()  || q(),
                $_->dsn(),
                $mapmaster,
                $_->description() || $_->config->{'description'} || $_->dsn() || q();

    } sort { $a->dsn() cmp $b->dsn() } $config->adaptors()]});
    $response->content($WRAPPERS->{'dsn'}->{'open'}.$dsnxml.$WRAPPERS->{'dsn'}->{'close'});

  } elsif($uri eq q(/)) {
    $response->content_type('text/html');
    $response->code(200);
    my $content = qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <title>Welcome to ProServer v$VERSION</title>
    <style type="text/css">
html,body{background:#ffc;font-family:helvetica,arial,sans-serif;}
thead{background-color:#700;color:#fff;}
thead th{margin:0;padding:2px;}
a{color:#a00;}a:hover{color:#aaa;}
.cite ul{list-style:none;padding:0;margin:0;}.cite li{display:inline;font-style:oblique;padding-right:0.5em;}
.cite{margin-bottom:1em;}
    </style>
  </head>
  <body><h1>Welcome to ProServer v$VERSION</h1>
<i>Core by Roger Pettett &copy; Genome Research Ltd.</i><br /><br />
<div class="cite">
<b>ProServer: A simple, extensible Perl DAS server.</b><br />
<ul><li>Finn RD,</li><li>Stalker JW,</li><li>Jackson DK,</li><li>Kulesha E,</li><li>Clements J,</li><li>Pettett R.</li></ul>
Bioinformatics 2007; <a href="http://bioinformatics.oxfordjournals.org/cgi/content/abstract/btl650v1">doi: 10.1093/bioinformatics/btl650</a>; PMID: 17237073</div>
Perform a <a href="das/dsn">DSN</a> request.\n);

    if(scalar $config->adaptors()) {
      $content .= qq(<table><thead><tr><th>Source</th><th>Mapmaster</th><th>Description</th><th>Capabilities</th></tr></thead><tbody>
@{[map {
  my $mm = $_->mapmaster() || $_->config->{'mapmaster'};
  $mm    = $mm?qq(<a href="$mm">$mm</a>):'-';
  sprintf qq(<tr><td><a href="das/%s">%s</a></td><td>%s</td><td>%s</td><td>%s</td></tr>\n),
  $_->dsn(), $_->dsn(),
  $mm,
  $_->description()      || $_->config->{'description'} || '-',
  $_->das_capabilities() || '-';
} $config->adaptors()]}
</tbody></table>\n);
    } else {
      $content .= qq(<br /><b>No adaptors configured.</b>\n);
    }

    $content .= '<ul>';
    for my $module ('Bio::Das::ProServer',
		    'Bio::Das::ProServer::SourceAdaptor',
		    'Bio::Das::ProServer::SourceHydra',
		    (map { 'Bio::Das::ProServer::'.$_ }                           sort keys %Bio::Das::ProServer::),
		    (map { 'Bio::Das::ProServer::SourceAdaptor::'.$_ }            sort keys %Bio::Das::ProServer::SourceAdaptor::),
		    (map { 'Bio::Das::ProServer::SourceAdaptor::Transport::'.$_ } sort keys %Bio::Das::ProServer::SourceAdaptor::Transport::),
		    (map { 'Bio::Das::ProServer::SourceHydra::'.$_ }              sort keys %Bio::Das::ProServer::SourceHydra::),
		   ) {
      next if($module !~ /::$/mx);
      my $cpkg = substr $module, 0, -2;
      my $str  = $cpkg->VERSION;
      my $vers = $str?"v$str":'unknown version';
      $content .= qq(<li>$cpkg $vers</li>\n);
    }

    $content .= qq(
</ul>

<br /><br /><br />
<center><small><a href="http://www.sanger.ac.uk/proserver/">ProServer homepage</a> | <a href="http://www.dasregistry.org/">DAS registry</a> | <a href="http://biodas.org/">BioDAS.org</a></small></center>
</body>
</html>\n);

    $response->content($content);

  } elsif(substr($uri, 0, 5) ne '/das/') {
    $response->content_type('text/plain');
    $response->code(403);
    $response->content('forbidden');

  } else {
    $response->content_type('text/plain');
    $response->content(qq(unimplemented. uri=@{[$uri||q()]}, dsn=@{[$dsn||q()]}, call=@{[$call||q()]}));
  }

  #########
  # Add custom X-DAS headers
  #
  $response->header('X-DAS-Version'      => '1.0');
  $response->header('X-DAS-Status'       => $response->code()||q());

  if($dsn && $config->knows($dsn)) {
    $response->header('X-DAS-Capabilities' => $config->adaptor($dsn)->das_capabilities()||q());
  }
  #
  # Finished handling das responses
  #########

  #########
  # Generate access log
  #
  my $logline   = $heap->{'self'}->{'logformat'};
  $logline      =~ s/%i/inet_ntoa($heap->{peer_addr})/emx;               # remote ip
  $logline      =~ s/%h/gethostbyaddr($heap->{peer_addr}, AF_INET);/emx; # remote hostname
  $logline      =~ s/%t/strftime '%Y-%m-%dT%H:%M:%S', localtime/emx;     # datetime yyyy-mm-ddThh:mm:ss
  $logline      =~ s/%r/$uri/mx;                                         # request uri
  $logline      =~ s/%>?s/@{[$response->code()]}/mx;                     # status

  if($heap->{'method'} &&
     $heap->{'method'} eq 'cgi') {
    print {*STDERR} $logline, "\n";

  } else {
    print $logline, "\n";
  }

  return $response;
}

### The client handler received an error.  Stop the ReadWrite wheel,
### which also closes the socket.

sub client_got_error {
  my ( $heap, $operation, $errnum, $errstr ) = @_[ HEAP, ARG0, ARG1, ARG2 ];
  DEBUG and
    carp( "Client handler $PID/", $_[SESSION]->ID,
	  " got $operation error $errnum: $errstr\n",
	  "Client handler $PID/", $_[SESSION]->ID, " is shutting down.\n"
	);
  return delete $heap->{client};
}

### The client handler has flushed its response to the socket.  We're
### done with the client connection, so stop the ReadWrite wheel.

sub client_flushed_request {
  my $heap = $_[HEAP];
  DEBUG and
    carp( "Client handler $PID/", $_[SESSION]->ID,
	  " flushed its response.\n",
	  "Client handler $PID/", $_[SESSION]->ID, " is shutting down.\n"
	);
  return delete $heap->{client};
}

### We're done.

sub make_pidfile {
  my ($self, $pidfile) = @_;
  my ($spidfile) = $pidfile =~ /([a-zA-Z0-9\.\/_\-]+)/mx;
  print {*STDERR} qq(Writing pidfile $spidfile\n);
  open my $fh, '>', $spidfile or croak "Cannot create pid file: $!\n";
  print {$fh} "$PID\n";
  close $fh;
  return $PID;
}

sub remove_pidfile {
  my ($self)     = @_;
  my $pidfile    = $self->{'pidfile'};
  my ($spidfile) = $pidfile =~ /([a-zA-Z0-9\.\/_\-]+)/mx;
  if(-f $spidfile) {
    unlink $spidfile;
    DEBUG and carp 'Removed pidfile';
  }
  return;
}

__END__

=head1 NAME

  Bio::Das::ProServer

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

=head1 USAGE

  eg/proserver

=head1 DESCRIPTION

  ProServer is a server implementation of the DAS protocol.

  ProServer os based on example preforking POEserver at
  http://poe.perl.org/?POE_Cookbook/Web_Server_With_Forking

=head1 REQUIRED ARGUMENTS

  None

=head1 OPTIONS

  See -h

=head1 DIAGNOSTICS

  To run in non-pre-forking, debug mode:
  eg/proserver -debug -x

  Otherwise stdout logs to proserver-hostname.log and stderr to proserver-hostname.err

=head1 EXIT STATUS

=head1 CONFIGURATION

  See eg/proserver.ini

=head1 DEPENDENCIES

  See Makefile.PL

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 GRL (The Sanger Institute)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

