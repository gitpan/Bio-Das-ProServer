#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2003-05-27
#
# Transport layer for DBI
#
package Bio::Das::ProServer::SourceAdaptor::Transport::dbi;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use base "Bio::Das::ProServer::SourceAdaptor::Transport::generic";
use DBI;

=head2 dbh : Database handle (mysqlish by default)

  my $dbh = Bio::Das::ProServer::SourceAdaptor::Transport::dbi->dbh();

=cut
sub dbh {
  my $self     = shift;
  my $host     = $self->config->{'host'}     || "localhost";
  my $port     = $self->config->{'port'}     || "3306";
  my $dbname   = $self->config->{'dbname'};
  my $username = $self->config->{'username'} || "test";
  my $password = $self->config->{'password'} || "";
  my $driver   = $self->config->{'driver'}   || "mysql";
  my $dsn      = qq(DBI:$driver:database=$dbname;host=$host;port=$port);

  #########
  # DBI connect_cached is slightly smarter than us just caching here
  #
  eval {
    $self->{'dbh'} = DBI->connect_cached($dsn, $username, $password, {RaiseError => 1});
  };
  if($@) {
    print STDERR "dsn = ", $self->{'dsn'},"\n";
    die $@;
  }
  return $self->{'dbh'};
}

=head2 query : Execute a given query with given args

  my $arrayref = $dbitransport->query(qq(SELECT ... WHERE x = ? AND y = ?),
				      $x,
				      $y);
=cut
sub query {
  my ($self, $query, @args) = @_;
  my $ref                   = [];
  my $retries               = 3;
  my $debug                 = $self->{'debug'};

  while($retries > 0) {
    $SIG{ALRM} = sub { die "timeout"; };
    alarm(30);
    eval {
      $debug and print STDERR "Preparing query...\n";
      my $sth = $self->dbh->prepare_cached($query);
      $debug and print STDERR "Executing query...\n";
      $sth->execute(@args);
      $debug and print STDERR "Fetching results...\n";
      $ref    = $sth->fetchall_arrayref({});
      $debug and print STDERR "Finishing...\n";
      $sth->finish();
    };
    alarm(0);
    if($@) {
      warn "Error running query (retries=$retries): $@\nArgs were: @{[join(' ', @_)]}\n";
      $retries --;

    } else {
      last;
    }
  }
  return $ref;
}

=head2 prepare : DBI pass-through of 'prepare'

  my $sth = $dbitransport->prepare($query);

=cut
sub prepare {
  my $self = shift;
  return $self->dbh->prepare(@_);
}

=head2 disconnect : DBI pass-through of disconnect

  $dbitransport->disconnect();

=cut
sub disconnect {
  my $self = shift;
  return unless (exists $self->{'dbh'});
  $self->{'dbh'}->disconnect();
  delete $self->{'dbh'};
}

1;
