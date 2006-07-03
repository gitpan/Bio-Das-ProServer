#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-12-12
# Last Modified: 2003-12-12
#
# DBI-driven sourceadaptor broker
#
package Bio::Das::ProServer::SourceHydra::dbi;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2005 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use base "Bio::Das::ProServer::SourceHydra";
our $CACHE_TIMEOUT = 30;

=head2 sources : DBI sources

  Effectively returns the results of a SHOW TABLES LIKE '$basename%'
  query. In Oracle I guess this would need changing to table_name from
  all_tables where like '$basename%' or something.

  my @sources = $dbihydra->sources();

  $basename comes from $self->config->{'basename'};

  This routine caches results for $CACHE_TIMEOUT as show tables can be
  slow for a few thousand sources.

=cut
#########
# the purpose of this module:
#
sub sources {
  my ($self)   = @_;
  my $basename = $self->config->{'basename'};
  my $dsn      = $self->{'dsn'};
  my $now      = time();

  #########
  # flush the table cache *at most* once every $CACHE_TIMEOUT
  # This may need signal triggering to have immediate support
  #
  if($now > $self->{'_tablecache_timestamp'}+$CACHE_TIMEOUT) {
    $self->{'debug'} and warn qq(Flushing table-cache for $dsn);
    delete($self->{'_tables'});
    $self->{'_tablecache_timestamp'} = $now;
  }

  #########
  # skip any management tables (which shouldn't begin with $basename!)
  #
  if(!exists $self->{'_tables'}) {
    $self->{'_tables'} = [];
    eval {
      my $l = length($basename);
      $self->{'debug'} and warn qq(Fetching tables like $basename%);
      my $sth = $self->transport->dbh->prepare(qq(SHOW TABLES LIKE "$basename%"));
      $sth->execute();
      $self->{'_tables'} = [map { substr($_->[0], 0, $l) = ""; $dsn.$_->[0]; } @{$sth->fetchall_arrayref()}];
      $sth->finish();
      $self->{'debug'} and warn qq(@{[scalar @{$self->{'_tables'}}]} tables found);
    };

    if($@) {
      warn "Error scanning tables: $@";
      delete $self->{'_tables'};
    }
  }

  return @{$self->{'_tables'} || []};
}

1;
