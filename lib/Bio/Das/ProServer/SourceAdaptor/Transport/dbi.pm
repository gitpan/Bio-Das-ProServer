#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $
# Id:            $Id: dbi.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/Transport/dbi.pm $
#
# Transport layer for DBI
#
package Bio::Das::ProServer::SourceAdaptor::Transport::dbi;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use DBI;
use Carp;
use English qw(-no_match_vars);

our $VERSION = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub dbh {
  my $self     = shift;
  my $config   = $self->config();
  my $host     = $config->{dbhost}  || $config->{host}     || 'localhost';
  my $port     = $config->{dbport}  || $config->{port}     || '3306';
  my $dbname   = $config->{dbname};
  my $username = $config->{dbuser}  || $config->{username} || 'test';
  my $password = $config->{dbpass}  || $config->{password} || q();
  my $driver   = $config->{driver}  || 'mysql';
  my $dsn      = "DBI:$driver:database=$dbname;host=$host;port=$port";

  #########
  # DBI connect_cached is slightly smarter than us just caching here
  #
  eval {
    if(!$self->{dbh} ||
       !$self->{dbh}->ping()) {
      $self->{dbh} = DBI->connect_cached($dsn, $username, $password, {RaiseError => 1});
    }
  };

  if($EVAL_ERROR) {
    croak "$dsn = $self->{dsb}\n$EVAL_ERROR";
  }

  return $self->{dbh};
}

sub query {
  my ($self,
      $query,
      @args)       = @_;
  my $ref          = [];
  my $debug        = $self->{debug};
  my $fetchall_arg = {};
  (@args and ref $args[0]) and $fetchall_arg = shift @args;

  $SIG{ALRM} = sub { croak 'timeout'; };
  alarm 30;
  eval {
    $debug and carp "Preparing query...\n";
    my $sth;
    if($query =~ /\?/mx) {
      $sth = $self->dbh->prepare_cached($query);
    } else {
      $sth = $self->dbh->prepare($query);
    }

    $debug and carp "Executing query...\n";
    $sth->execute(@args);
    $debug and carp "Fetching results...\n";
    $ref    = $sth->fetchall_arrayref($fetchall_arg);
    $debug and carp "Finishing...\n";
    $sth->finish();
  };
  alarm 0;

  if($EVAL_ERROR) {
    croak "Error running query: $EVAL_ERROR\nArgs were: @{[join q( ), @_]}\n";
  }

  return $ref;
}

sub prepare {
  my ($self, @args) = @_;
  return $self->dbh->prepare(@args);
}

sub disconnect {
  my $self = shift;

  if(!exists $self->{dbh} || !$self->{dbh}) {
    return;
  }

  $self->{dbh}->disconnect();
  delete $self->{dbh};
  $self->{debug} and carp "$self performed dbh disconnect\n";
  return;
}

sub last_modified {
  my $self = shift;

  if($self->dbh->{Driver}->{Name} ne 'mysql') {
    return;
  }

  my $server_text = [sort { $b cmp $a } ## no critic
                     map { $_->{Update_time} }
                     @{ $self->query(q(SHOW TABLE STATUS),{Update_time=>1}) }
                    ]->[0]; # server local time
  my $server_unix = $self->query(q(SELECT UNIX_TIMESTAMP(?) as 'unix'), $server_text)->[0]{unix}; # sec since epoch
  return $server_unix;
}

sub DESTROY {
  my $self = shift;
  return $self->disconnect();
}

1;

__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::dbi - A DBI transport layer (actually customised for MySQL)

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 dbh - Database handle (mysqlish by default)

  my $dbh = Bio::Das::ProServer::SourceAdaptor::Transport::dbi->dbh();

=head2 query - Execute a given query with given args

  my $arrayref = $dbitransport->query(qq(SELECT ... WHERE x = ? AND y = ?),
				      $x,
				      $y);

=head2 prepare - DBI pass-through of 'prepare'

  my $sth = $dbitransport->prepare($query);

=head2 disconnect - DBI pass-through of disconnect

  $dbitransport->disconnect();

=head2 last_modified - machine time of last data change

  $dbitransport->last_modified();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
