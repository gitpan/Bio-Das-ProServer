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

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 dbh : Oracle database handle

  Overrides Transport::dbi::dbh method

  my $dbh = Bio::Das::ProServer::SourceAdaptor::Transport::oracle->dbh();

=cut
sub dbh {
  my $self       = shift;
  my $dbname     = $self->config->{'dbname'};
  my $host       = $self->config->{'dbhost'} || $self->config->{'host'}; # optional
  my $sid        = $self->config->{'dbsid'}  || $self->config->{'sid'};  # optional
  my $port       = $self->config->{'dbport'} || $self->config->{'port'}; # optional
  my $username   = $self->config->{'dbuser'} || $self->config->{'username'};
  my $password   = $self->config->{'dbpass'} || $self->config->{'password'};
  my $driver     = $self->config->{'driver'} || 'Oracle';
  my $dsn        = "DBI:$driver:";
  
  if (defined $host && defined $sid) {
    $dsn .= "host=$host;sid=$sid";
    $dsn .= ";port=$port" if (defined $port);
  }
  else {
    $dsn .= $dbname;
  }
  
  if(!$self->{'dbh'} ||
     !$self->{'dbh'}->ping()) {
    $self->{'dbh'} = DBI->connect_cached($dsn, $username, $password, {RaiseError => 1});
  }
  return $self->{'dbh'};
}

1;
