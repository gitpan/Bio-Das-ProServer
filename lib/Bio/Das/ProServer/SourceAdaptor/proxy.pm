#########
# Author: dj3 
# Maintainer: dj3
# Created: 2005-10-21
# Last Modified: 2005-10-21
# Passes through all requests to another das server
# Intended to be inherited from by proxies which do more interesting things

package Bio::Das::ProServer::SourceAdaptor::proxy;

use strict;
use vars qw(@ISA);
use HTTP::Request;
use LWP::UserAgent;
use Bio::DasLite;
use Data::Dumper;
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

################################################################################
sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'   => '1.0',
			     'stylesheet' => '1.0',
			    };
}

sub das_stylesheet {
  my $self                = shift;
  return LWP::UserAgent->new->request(HTTP::Request->new("GET",$self->config->{'sourcedsn'}."/stylesheet"))->content;
}

sub build_features {
  my ($self, $opts) = @_;
  my $seg     = $opts->{'segment'};
  my $start   = $opts->{'start'};
  my $end     = $opts->{'end'};

  my $das = Bio::DasLite->new({
			       'dsn' => $self->config->{'sourcedsn'},
			      });
  my @results=();
  $das->features((exists(${$opts}{'start'})?"$seg:$start,$end":"$seg"), sub{my $fr=shift; push @results,$fr if $fr->{feature_id}});
  return @results;
}

1;
