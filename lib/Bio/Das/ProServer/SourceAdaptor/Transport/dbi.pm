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
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use DBI;
use HTTP::Date;

our $VERSION = do { my @r = (q$Revision: 2.53 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

=head2 dbh : Database handle (mysqlish by default)

  my $dbh = Bio::Das::ProServer::SourceAdaptor::Transport::dbi->dbh();

=cut
sub dbh {
  my $self     = shift;
  my $config   = $self->config();
  my $host     = $config->{'dbhost'}   || $config->{'host'}     || 'localhost';
  my $port     = $config->{'dbport'}   || $config->{'port'}     || '3306';
  my $dbname   = $config->{'dbname'};
  my $username = $config->{'dbuser'}   || $config->{'username'} || 'test';
  my $password = $config->{'dbpass'}   || $config->{'password'} || '';
  my $driver   = $config->{'driver'}   || 'mysql';
  my $dsn      = "DBI:$driver:database=$dbname;host=$host;port=$port";

  #########
  # DBI connect_cached is slightly smarter than us just caching here
  #
  eval {
    if(!$self->{'dbh'} ||
       !$self->{'dbh'}->ping()) {
      $self->{'dbh'} = DBI->connect_cached($dsn, $username, $password, {RaiseError => 1});
    }
  };
  if($@) {
    print STDERR 'dsn = ', $self->{'dsn'},"\n";
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
  print STDERR "@args \n";
  my $ref                   = [];
  my $retries               = 3;
  my $debug                 = $self->{'debug'};
  my $fetchall_arg          = {};
  (@args and ref $args[0]) and $fetchall_arg = shift @args;

  while($retries > 0) {
    $SIG{ALRM} = sub { die 'timeout'; };
    alarm(30);
    eval {
      $debug and print STDERR "Preparing query...\n";
      my $sth;
      if($query =~ /\?/) {
	$sth = $self->dbh->prepare_cached($query);
      } else {
	$sth = $self->dbh->prepare($query);
      }
      $debug and print STDERR "Executing query...\n";
      $sth->execute(@args);
      $debug and print STDERR "Fetching results...\n";
      $ref    = $sth->fetchall_arrayref($fetchall_arg);
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
  $self->{'debug'} and print STDERR "$self performed dbh disconnect\n";
}

=head2 last_modified : machine time of last data change

  $dbitransport->last_modified();

=cut
sub last_modified {
  my $self = shift;
  $self->dbh->{Driver}->{Name} eq 'mysql' or return undef ; #Only know MySQL way at the moment....
  return [sort{$b<=>$a}map{str2time $_->{Update_time}}@{$self->query("SHOW TABLE STATUS",{Update_time=>1})}]->[0];
}

sub DESTROY {
  my $self = shift;
  $self->disconnect();
}

1;
