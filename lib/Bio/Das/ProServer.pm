#!/usr/local/bin/perl
#########
# ProServer DAS Server
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2003-05-22
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Source:        $Source $
# Id:            $Id $
#

package Bio::Das::ProServer;
use warnings;
use strict;
use Bio::Das::ProServer::Config;
use CGI qw(:cgi);
use HTTP::Request;
use HTTP::Response;
use Compress::Zlib;
use Getopt::Long;
use POE;                         # Base features.
use POE::Filter::HTTPD;          # For serving HTTP content.
use POE::Wheel::ReadWrite;       # For socket I/O.
use POE::Wheel::SocketFactory;   # For serving socket connections.
use POSIX qw(setsid strftime);
use File::Spec;
use Sys::Hostname;
use Bio::Das::ProServer::SourceAdaptor;
use Bio::Das::ProServer::SourceHydra;
use Socket;
use English qw(-no_match_vars);
use Carp;

our $DEBUG          = 0;
our $VERSION        = do { my @r = (q$Revision: 2.70 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };
our $GZIP_THRESHOLD = 10_000;
$ENV{'PATH'}        = '/bin:/usr/bin:/usr/local/bin';
our $WRAPPERS       = {
		       'sources'      => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<?xml-stylesheet type="text/xsl" href="sources.xsl"?>\n<SOURCES>\n),
					  'close' => qq(</SOURCES>\n),
					 },
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
		       'interaction'  => {
					  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<DASINT>\n),
                                          'close' => qq(</DASINT>\n),
					 },
		       'volmap'       => {
			                  'open'  => qq(<?xml version="1.0" standalone="no"?>\n<!DOCTYPE DASVOLMAP SYSTEM "http://biocomp.cnb.uam.es/das/dtd/dasvolmap.dtd">\n<DASVOLMAP version="1.0">\n),
					  'close' => qq(</DASVOLMAP>\n),
					 },
		       'stylesheet'   => {
					  'open'  => q(),
					  'close' => q(),
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
                               pidfile=s
                               logfile=s
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

  my $maxmsg = (sort { $a <=> $b } map { length $_ } @msg)[-1];

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
 -pidfile <*>     # Use this process ID file (overides configuration file)
 -logfile <*>     # Use this log file (overides configuration file)
 -help            # This help
 -config          # Use this configuration file
 -x               # Development mode - disables server forking
 
 To stop the server:
   kill -TERM `cat eg/proserver.myhostname.pid`

 To restart the server:
   kill -USR1 `cat eg/proserver.myhostname.pid`\n\n);
    return;
  }

  if(!$opts->{'inifile'}) {
    $opts->{'inifile'} = File::Spec->catfile('eg', 'proserver.ini');
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

  # Load in the co-ordinates file
  my $coord_dir   = $config->{'coordshome'};
  my %all_coords = ();

  for my $coordfile ( glob File::Spec->catfile($coord_dir, '*.xml') ) {
    open my $fh_coord, q(<), $coordfile or croak "Unable to open coordinates file $coordfile";
    my @coordfull = split m|</COORDINATES>|mx,
                           join q(),
                                grep { (s|^\s*(<\?xml.*?>)?(\s*</?DASCOORDINATESYSTEM>\s*)?||mix || $_) &&
				       (s/\s*$//mx || $_) &&
				       $_ } <$fh_coord>;
    close $fh_coord or croak "Unable to close coordinates file $coordfile";

    my %coords;
    for (@coordfull) {
      my ($uri) = m/uri\s*=\s*"(.*?)"/mx;
      my ($des) = m/>(.*)$/mx;
      $coords{lc $des} = $coords{lc $uri} = {
        'uri'         => $uri,
        'description' => $des,
        'source'      => my ($t) = m/source\s*=\s*"(.*?)"/mx,
        'authority'   => my ($a) = m/authority\s*=\s*"(.*?)"/mx,
        'version'     => my ($v) = m/version\s*=\s*"(.*?)"/mx,
        'taxid'       => my ($s) = m/taxid\s*=\s*"(.*?)"/mx,
      };
    }
    print {*STDERR} q(Loaded ).((scalar keys %coords)/2)." co-ordinate systems from $coordfile\n";
    %all_coords = (%all_coords, %coords);
  }
  $self->{'coordinates'} =\%all_coords;
  
  if(!$opts->{'X'} && fork) {
    print {*STDERR} qq(Parent process detached...\n);
    return;

  } elsif($opts->{'X'}) {
    $config->maxclients(0);
  }

  setsid() or croak 'Cannot setsid';

  my $pidfile = $opts->{'pidfile'} || $config->pidfile() || sprintf '%s.%s.pid', $PROGRAM_NAME||'proserver', hostname() || 'localhost';
  $self->make_pidfile($pidfile);
  
  my $logfile = $opts->{'logfile'} || $config->logfile();
  if (!defined $logfile) {
    my ($vol, $path) = File::Spec->splitpath($pidfile);

    if(!$path) {
      ($vol, $path) = File::Spec->splitpath($opts->{'inifile'});
    }

    $logfile = File::Spec->catpath($vol, $path, sprintf 'proserver.%s.log', hostname() );
  }

  open STDIN, '<', File::Spec->devnull or croak "Can't open STDIN from the null device: [$!]";
  if(!$opts->{'X'}) {
    my $errlog = $logfile;
    $errlog    =~ s/\.log$/.err/mx;
    print {*STDERR} qq(Logging STDOUT to $logfile and STDERR to $errlog\n);
    open STDOUT, '>', $logfile or croak "Can't open STDOUT to $logfile: [$!]";
    open STDERR, '>', $errlog  or croak "Can't open STDERR to STDOUT: [$!]";
  }

  if(exists $config->{'ensemblhome'}) {
    my ($eroot) = $config->{'ensemblhome'} =~ m|([a-zA-Z0-9_/\.\-]+)|mx;
    $ENV{'ENS_ROOT'}     = $eroot;
    unshift @INC, File::Spec->catdir($eroot, 'ensembl' , 'modules');
    print {*STDERR} qq(Set ENS_ROOT to $ENV{'ENS_ROOT'}\n);
  }

  if(exists $config->{'oraclehome'}) {
    $ENV{'ORACLE_HOME'}  = $config->{'oraclehome'};
    print {*STDERR} qq(Set ORACLE_HOME to $ENV{'ORACLE_HOME'}\n);
  }

  if(exists $config->{'bioperlhome'}) {
    my ($broot) = $config->{'bioperlhome'} =~ m|([a-zA-Z0-9_/\.\-]+)|mx;
    $ENV{'BIOPERL_HOME'} = $broot;
    unshift @INC, $broot;
    print {*STDERR} qq(Set BIOPERL_HOME to $ENV{'BIOPERL_HOME'}\n);
  }

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

sub response_xsl {
  my ($heap, $request, $response, $call) = @_;
  my $config   = $heap->{'self'}->{'config'};
  $response->content_type('text/xsl');
  $response->content($config->adaptor()->das_xsl({'call'=>$call}));
  return;
}

sub response_general {
  my ($heap, $request, $response, $dsn, $call) = @_;
  
  my $method   = "das_$call";
  if(substr($call, -3, 3) eq 'xsl') {
    $method = 'das_xsl';
    $response->content_type('text/xsl');

  } elsif($call eq 'homepage') {
    $response->content_type('text/html');
  }

  my $cgi;
  my $http_method = lc $request->method();

  #########
  # process the parameters
  #
  if ($http_method eq 'get') {
    my ($query) = $request->uri() =~ /\?(.*)$/mx;
    $cgi = CGI->new($query);

  } elsif ($http_method eq 'post') {
    $cgi = CGI->new($request->{'_content'}); ## Nasty - should use some sort of raw_content method
  }

  my $config  = $heap->{'self'}->{'config'};
  my $adaptor = $config->adaptor($dsn);
  my $query   = {
		 # Features command / shared:
		 'segments'    => [$cgi->param('segment')],
		 'features'    => [$cgi->param('feature_id')],
		 'groups'      => [$cgi->param('group_id')],
		 'maxbins'     => $cgi->param('maxbins') || undef,
		 'call'        => $call,
		 # Alignment command:
		 'query'       => $cgi->param('query') || undef,
		 'subjects'    => [$cgi->param('subject')],
		 'rows'        => $cgi->param('rows') || undef,
		 'subcoos'     => $cgi->param('subjectcoordsys') || undef,
		 # Structure command:
		 'chains'      => [$cgi->param('chain')],
		 'ranges'      => [$cgi->param('range')], # Note: not supported!
		 'model'       => [$cgi->param('model')],
		 # Interaction command:
		 'interactors' => [$cgi->param('interactor')],
		 'details'     => [$cgi->param('detail')],
		 # Sources command:
		 'allcoos'     => $heap->{'self'}->{'coordinates'} || {},
		};

  eval {
    if($adaptor->implements($call) ||
       $call   eq 'homepage'       ||
       $method eq 'das_xsl') {
    
      my $use_gzip = 0;
      if($call   ne 'homepage' &&
         $call   ne 'dsn'      &&
         $method ne 'das_xsl' ) {

        my $enc = $request->header('Accept-Encoding') || q();
        if($enc =~ /gzip/mix) {
	  DEBUG and carp 'Client accepts compression';
	  $use_gzip = 1;
        }
      }

      my $head    = $WRAPPERS->{$call}->{'open'}  || q();
      my $foot    = $WRAPPERS->{$call}->{'close'} || q();
      my $subst   = {
		     'host'     => $config->response_hostname(),
		     'port'     => $config->response_port()     || q(),
		     'protocol' => $config->response_protocol() || 'http',
		     'baseuri'  => $config->response_baseuri()  || q(),
		     'dsn'      => $dsn,
		    };
      $head       =~ s/\%([a-z]+)/$subst->{$1}/smgxi;
      $response->last_modified($adaptor->dsncreated_unix);
      my $content = $head.$adaptor->$method($query).$foot;

      if($use_gzip && (length $content > $GZIP_THRESHOLD)) {
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

      $response->content($content);

    } elsif($call eq 'stylesheet') {
      $response->content_type('text/plain');
      $response->header('X-DAS-Status' => 404);
      $response->content('Bad stylesheet (requested stylesheet unknown)');

    } elsif(not exists $WRAPPERS->{$call}) {
      $response->content_type('text/plain');
      $response->header('X-DAS-Status' => 400);
      $response->content("Bad command (command not recognized: $call)");

    } else {
      $response->content_type('text/plain');
      $response->header('X-DAS-Status' => 501);
      $response->content(qq(Unimplemented command for $dsn: @{[$call||q()]}));
    }
  };

  if($EVAL_ERROR) {
    carp $EVAL_ERROR;
    $response->content_type('text/plain');
    $response->code(500); #?
    $response->header('X-DAS-Status' => 500);
    $response->content("Bad data source $dsn (error processing command: $call)");
  }

  return;
}

sub response_dsn {
  my ($heap, $request, $response) = @_;
  my $config  = $heap->{'self'}->{'config'};
  my $resp = $WRAPPERS->{'dsn'}->{'open'};
  for my $adaptor (sort { lc $a->dsn cmp lc $b->dsn } grep { defined $_ } $config->adaptors()) {
    $resp .= $adaptor->das_dsn();
  }
  $resp .= $WRAPPERS->{'dsn'}->{'close'};
  $response->content($resp);
  return;
}

sub response_sources {
  my ($heap, $request, $response, $call) = @_;
  # Note that structure of 'sources' call is backwards (baseuri/das/sources/<dsn>)
  my $config  = $heap->{'self'}->{'config'};
  my %data;
  grep {
    defined $_ &&
    ($call eq 'homepage' || $call eq $_->dsn || $call eq $_->source_uri || $call eq $_->version_uri) &&
    ($data{$_->source_uri}{$_->version_uri} = $_);
  } $config->adaptors();
  
  my $resp = $WRAPPERS->{'sources'}->{'open'};
  while (my ($s_uri, $s_data) = each %data) {
    my @versions = keys %{$s_data};

    for (my $i=0; $i<scalar @versions; $i++) {
      eval {
        $resp .= $s_data->{$versions[$i]}->das_sourcedata({
          'skip_open'  => $i > 0,
          'skip_close' => $i+1 < scalar @versions,
          'allcoos'    => $heap->{'self'}->{'coordinates'},
        });
      };
      if ($EVAL_ERROR) {
        carp "Error generating source data for '$versions[$i]':\n$EVAL_ERROR\n";
      }
    }
  }
  $resp .= $WRAPPERS->{'sources'}->{'close'};
  $response->content($resp);
  return;
}

sub response_homepage {
  my ($heap, $request, $response) = @_;
  my $config  = $heap->{'self'}->{'config'};
  $response->content_type('text/html');
  my $content = qq(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html>
  <head>
    <title>Welcome to ProServer v$VERSION</title>
    <style type="text/css">
html,body{background:#ffc;font-family:helvetica,arial,sans-serif}
thead{background-color:#700;color:#fff}
thead th{margin:0;padding:2px}
a{color:#a00;}a:hover{color:#aaa}
.cite ul{list-style:none;padding:0;margin:0;}.cite li{display:inline;font-style:oblique;padding-right:0.5em}
.cite{margin-bottom:1em}
    </style>
  </head>
  <body><h1>Welcome to ProServer v$VERSION</h1>
<i>Core by Roger Pettett &copy; Genome Research Ltd.</i><br /><br />
<div class="cite">
<b>ProServer: A simple, extensible Perl DAS server.</b><br />
<ul><li>Finn RD,</li><li>Stalker JW,</li><li>Jackson DK,</li><li>Kulesha E,</li><li>Clements J,</li><li>Pettett R.</li></ul>
Bioinformatics 2007; <a href="http://bioinformatics.oxfordjournals.org/cgi/content/abstract/btl650v1">doi: 10.1093/bioinformatics/btl650</a>; PMID: 17237073</div>
);

  my $maintainer = $config->{'maintainer'};
  if ($maintainer) {
    $content .= qq(<p>This server is maintained by <a href="mailto:$maintainer">$maintainer</a>.</p>\n);
  } else {
    $content .= qq(<p>This server has no configured maintainer.</p>\n);
  }
  
  $content .= sprintf q(<p>Perform a <a href="%s://%s:%s%s/das/dsn">DSN</a> or <a href="%1$s://%2$s:%3$s%4$s/das/sources">SOURCES</a> request.</p>)."\n",
  $config->response_protocol, $config->response_hostname, $config->response_port, $config->response_baseuri;
  if(scalar $config->adaptors()) {
    $content .= qq(<table><thead><tr><th>Source</th><th>Mapmaster</th><th>Description</th><th>Capabilities</th></tr></thead><tbody>
@{[map {
  my $mm = $_->mapmaster();
  $mm    = $mm?qq(<a href="$mm">$mm</a>):'-';
  sprintf q(<tr><td><a href="%s://%s:%s%s/das/%s">%5$s</a></td><td>%s</td><td>%s</td><td>%s</td></tr>)."\n",
  $config->response_protocol, $config->response_hostname, $config->response_port, $config->response_baseuri,
  $_->dsn(),
  $mm,
  $_->description(),
  $_->das_capabilities() || '-';
} sort { lc $a->dsn cmp lc $b->dsn } grep { defined $_ } $config->adaptors()]}
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

    if($module !~ /::$/mx) {
      next;
    }

    my $cpkg  = substr $module, 0, -2;
    my $str   = $cpkg->VERSION;
    my $vers  = $str?"v$str":'unknown version';
    $content .= qq(<li>$cpkg $vers</li>\n);
  }

  $content .= qq(
</ul>
<br /><br /><br />
<center><small><a href="http://www.sanger.ac.uk/proserver/">ProServer homepage</a> | <a href="http://www.dasregistry.org/">DAS registry</a> | <a href="http://biodas.org/">BioDAS.org</a></small></center>
</body>
</html>\n);

  $response->content($content);
  return;
}

sub build_das_response {
  my ($heap, $request) = @_;

  my $config = $heap->{'self'}->{'config'};

  #########
  # Handle DAS responses here
  #
  my $response     = HTTP::Response->new(200);
  $response->header('X-DAS-Server' => $config->server_version);
  $response->header('X-DAS-Status' => 200);
  $response->content_type('text/xml');
  my $uri          = $request->uri();
  my ($dsn, $call) = $uri =~ m|/das1?(?:/([^/\?\#]+))(?:/([^/\?\#]+))?|mx;
  $dsn           ||= q();

  if($dsn && !$call) {
    $call = 'homepage';
  }

  if($dsn eq 'dsn.xsl') {
    response_xsl($heap, $request, $response, 'dsn.xsl');
    
  } elsif($dsn eq 'sources.xsl' || $call eq 'sources.xsl') {
    response_xsl($heap, $request, $response, 'sources.xsl');
    
  } elsif($dsn && $config->knows($dsn)) {
    response_general($heap, $request, $response, $dsn, $call);
    
  } elsif($dsn eq 'sources') {
    response_sources($heap, $request, $response, $call);
    
  } elsif($dsn eq 'dsn') {
    response_dsn($heap, $request, $response);
    
  } elsif(!$dsn) {
    response_homepage($heap, $request, $response);
    
  } else {
    $response->content_type('text/plain');
    $response->header('X-DAS-Status' => 401);
    $response->content("Bad data source (data source unknown: $dsn)\nuri=@{[$uri||q()]}, dsn=@{[$dsn||q()]}, call=@{[$call||q()]}");
  }
  
  $response->content_length(length $response->content);

  #########
  # Add custom X-DAS headers
  #
  $response->header('X-DAS-Version'      => $config->das_version);

  if($dsn && $config->knows($dsn) && (my $adaptor = $config->adaptor($dsn))) {
    eval {
      $response->header('X-DAS-Capabilities' => $adaptor->das_capabilities()||q());
      $adaptor->cleanup();
    };
    $EVAL_ERROR && carp $EVAL_ERROR;
  }
  else {
    $response->header('X-DAS-Capabilities' => q(dsn/1.0; sources/1.0));
  }
  #
  # Finished handling das responses
  #########

  #########
  # Generate access log
  #
  my $logline = $heap->{'self'}->{'logformat'};
  $logline    =~ s/%i/inet_ntoa($heap->{peer_addr})/emx;                              # remote ip
  $logline    =~ s/%h/gethostbyaddr($heap->{peer_addr}, AF_INET);/emx;                # remote hostname
  $logline    =~ s/%t/strftime '%Y-%m-%dT%H:%M:%S', localtime/emx;                    # datetime yyyy-mm-ddThh:mm:ss
  $logline    =~ s/%r/$uri/mx;                                                        # request uri
  $logline    =~ s/%>?s/@{[$response->code(), $response->header('X-DAS-Status')]}/mx; # status

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
  $self->{'pidfile'} = $pidfile;
  open my $fh, '>', $spidfile or croak "Cannot create pid file: $ERRNO\n";
  print {$fh} "$PID\n";
  close $fh or carp "Error closing pid file: $ERRNO";
  return $PID;
}

sub remove_pidfile {
  my ($self)     = @_;
  my $spidfile    = $self->{'pidfile'};
  if($spidfile && -f $spidfile) {
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

  ProServer is based on example preforking POEserver at
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

