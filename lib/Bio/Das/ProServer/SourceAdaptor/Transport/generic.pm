#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-06-13
# Last Modified: 2003-06-13
#
# generic transport layer
#
package Bio::Das::ProServer::SourceAdaptor::Transport::generic;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;

=head2 new : base-class object constructor

  my $transport = Bio::Das::ProServer::SourceAdaptor::Transport::<impl>->new({
    'dsn'    => 'my-dsn-name',   # useful for hydras
    'config' => $config->{$dsn}, # subsection of config file for this adaptor holding this transport
  });

=cut
sub new {
  my ($class, $defs) = @_;
  my $self = {
	      'dsn'    => $defs->{'dsn'}    || "unknown",
              'config' => $defs->{'config'} || {},
             };
  bless $self, $class;

  $self->init();

  return $self;
}

=head2 init : Post-constructor initialisation hook

  By default does nothing - override in subclasses if necessary

=cut
sub init { }

=head2 config : Handle on config file (given at construction)

  my $cfg = $transport->config();

=cut
sub config {
  my $self = shift;
  return $self->{'config'};
}

=head2 query : Execute a query against this transport

  Unimplemented in base-class. You almost always want to override this

  my $resultref = $transport->query(...);

=cut
sub query { }

1;
