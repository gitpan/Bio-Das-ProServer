#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2003-05-27
#
# Transport layer for DBI
#
package Bio::Das::ProServer::SourceAdaptor::Transport::oracle;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::dbi);

our $VERSION = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 dbh : Oracle database handle

  Overrides Transport::dbi::dbh method

  my $dbh = Bio::Das::ProServer::SourceAdaptor::Transport::oracle->dbh();

=cut
sub dbh {
  my $self       = shift;
  my $dbname     = $self->config->{'dbname'};
  my $username   = $self->config->{'dbuser'} || $self->config->{'username'};
  my $password   = $self->config->{'dbpass'} || $self->config->{'password'};
  my $driver     = $self->config->{'driver'} || 'Oracle';
  my $dsn        = "DBI:$driver:";
  my $userstring = "$username\@$dbname";

  if(!$self->{'dbh'} ||
     !$self->{'dbh'}->ping()) {
    $self->{'dbh'} = DBI->connect_cached($dsn, $userstring, $password, {RaiseError => 1});
  }
  return $self->{'dbh'};
}

1;
