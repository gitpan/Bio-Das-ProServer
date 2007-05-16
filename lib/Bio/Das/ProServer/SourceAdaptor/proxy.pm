#########
# Author:        dj3
# Maintainer:    $Author: rmp $
# Created:       2005-10-21
# Last Modified: $Date: 2007/03/09 14:23:08 $
# Id:            $Id: proxy.pm,v 2.51 2007/03/09 14:23:08 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor/proxy.pm,v $
#
# Passes through all requests to another das server
# Intended to be inherited from by proxies which do more interesting things
#
package Bio::Das::ProServer::SourceAdaptor::proxy;
use strict;
use warnings;
use HTTP::Request;
use LWP::UserAgent;
use Bio::Das::Lite;
use base qw(Bio::Das::ProServer::SourceAdaptor);

our $VERSION = do { my @r = (q$Revision: 2.51 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub das_stylesheet {
  my $self = shift;
  return LWP::UserAgent->new->request(HTTP::Request->new('GET', $self->config->{'sourcedsn'}.'/stylesheet'))->content;
}

sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};
  my $das     = Bio::Das::Lite->new({
				     'dsn' => $self->config->{'sourcedsn'},
				    });
  my @results=();
  $das->features((exists(${$opts}{'start'})?"$seg:$start,$end":$seg), sub { my $fr = shift; push @results, $fr if $fr->{feature_id}});
  return @results;
}

1;
