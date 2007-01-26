#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-12-12
# Last Modified: 2003-12-12
#
# Dynamic SourceAdaptor broker
#
package Bio::Das::ProServer::SourceHydra;
use strict;
use warnings;
use Bio::Das::ProServer::SourceAdaptor;

our $VERSION  = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2006 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

=head1 PURPOSE

The SourceHydra's role is to clone a series of SourceAdaptors of the
same type but each configured in a (systematically) different way, but
with only one configuration file section.

For example the hydra is pivotal in the Ensembl upload service where
each data upload is of the same structure and loaded into a numbered
table in a database. In order to provide a valid DSN for each uploaded
source, the hydra then clones a series of dbi-based sources, pointing
them all at the upload database but each one at a different table.

The hydra can also be useful in situations such as the provision of
similar sources for different species where the data are in different
databases but have the same structure in each.

=head2 new : Constructor

  my $hydra = Bio::Das::ProServer::SourceHydra->new({
    'config' => $cfg, # The config section for this hydra
    'debug'  => $dbg, # Boolean debug flag
  });

=cut
sub new {
  my ($class, $defs) = @_;
  my $self = {
	      'dsn'    => $defs->{'dsn'}    || '',
              'config' => $defs->{'config'},
	      'debug'  => $defs->{'debug'}  || undef,
             };

  bless $self, $class;
  $self->init($defs);
  return $self;
}

=head2 init : Post-construction initialisation method

  Implemented in subclasses if necessary (not usually)

=cut
sub init { }

=head2 transport : Build the relevant transport configured for this adaptor

  my $transport = $hydra->transport();

=cut
sub transport {
  my $self = shift;

  if(!exists $self->{'_transport'} && $self->config->{'transport'}) {

    my $transport = 'Bio::Das::ProServer::SourceAdaptor::Transport::'.$self->config->{'transport'};
    eval "require $transport";
    if($@) {
      warn $@;
    } else {
      $self->{'_transport'} = $transport->new({
					       'config' => $self->config(),
					      });
    }
  }
  return $self->{'_transport'};
}

=head2 config : Accessor for config section for this hydra (set at construction)

  my $cfg = $hydra->config();

=cut
sub config {
  my ($self, $config) = @_;
  $self->{'config'}   = $config if($config);
  return $self->{'config'};
}

=head2 sources : Implemented in subclasses - returns an of source names

  my @sources = $hydra->sources();

=cut
sub sources {}

1;
