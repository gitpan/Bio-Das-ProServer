#!/usr/local/bin/perl
#########
# Author:        rmp
# Maintainer:    $Author: rmp $
# Created:       2003-05-22
# Last Modified: $Date: 2007/03/09 14:22:43 $
# Source:        $Source $
# Id:            $Id $
#
# ProServer DAS Server CGI handler
#
# loading and processing the proserver.ini can have high overheads
# so, as is, this might be best run inside FastCGI
#
package proserver;
use Bio::Das::ProServer;
use strict;
use warnings;
use Carp;

our $VERSION = do { my @r = (q$Revision: 1.1 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

main();
0;

sub main {
  if(!$ENV{'PROSERVER_CFG'}) {
    croak q(No PROSERVER_CFG configured in environment);
  }

  my ($cfgfile) = $ENV{'PROSERVER_CFG'} =~ m|([/_a-z\d\.\-]+)|mix;
  $cfgfile    ||= q();

  if($cfgfile ne $ENV{'PROSERVER_CFG'}) {
    croak "PROSERVER_CFG failed to detaint ($cfgfile)\n";
  }

  my $config   = Bio::Das::ProServer::Config->new({'inifile' => $cfgfile,});
  my $heap     = {'method' => 'cgi','self' => {'config' => $config,},};
  my $request  = HTTP::Request->new( 'GET', $ENV{'REQUEST_URI'}||q() );
  my $response = Bio::Das::ProServer::build_das_response($heap, $request);

  print $response->headers->as_string, "\n", $response->content();
  return;
}
