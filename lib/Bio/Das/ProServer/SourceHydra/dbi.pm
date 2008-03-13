#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-12-12
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $ $Author: andyjenkinson $
# Id:            $Id: dbi.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source: /nfs/team117/rmp/tmp/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceHydra/dbi.pm,v $
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceHydra/dbi.pm $
#
# DBI-driven sourceadaptor broker
#
package Bio::Das::ProServer::SourceHydra::dbi;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceHydra);
use English qw(-no_match_vars);
use Carp;

our $VERSION       = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };
our $CACHE_TIMEOUT = 30;

#########
# the purpose of this module:
#
sub sources {
  my ($self)   = @_;
  my $basename = $self->config->{'basename'};
  my $dsn      = $self->{'dsn'};
  my $now      = time;

  #########
  # flush the table cache *at most* once every $CACHE_TIMEOUT
  # This may need signal triggering to have immediate support
  #
  if($now > ($self->{'_tablecache_timestamp'} || 0)+$CACHE_TIMEOUT) {
    $self->{'debug'} and carp qq(Flushing table-cache for $dsn);
    delete $self->{'_tables'};
    $self->{'_tablecache_timestamp'} = $now;
  }

  #########
  # skip any management tables (which shouldn't begin with $basename!)
  #
  if(!exists $self->{'_tables'}) {
    $self->{'_tables'} = [];
    eval {
      my $l = length $basename;
      $self->{'debug'} and carp qq(Fetching tables like $basename%);

      my $sth = $self->transport->dbh->prepare(qq(SHOW TABLES LIKE "$basename%"));
      $sth->execute();

      $self->{'_tables'} = [map {
	$dsn.($_->[0] =~ /^.{$l}(.*)$/mx)[0];
      } @{$sth->fetchall_arrayref()}];

      $sth->finish();
      $self->{'debug'} and carp qq(@{[scalar @{$self->{'_tables'}}]} tables found);
    };

    if($EVAL_ERROR) {
      carp "Error scanning tables: $EVAL_ERROR";
      delete $self->{'_tables'};
    }
  }

  return @{$self->{'_tables'} || []};
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceHydra::dbi - A database-backed implementation of B::D::P::SourceHydra

=head1 VERSION

$Revision: 453 $

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=head1 DESCRIPTION

=head1 SYNOPSIS

  my $dbiHydra = Bio::Das::ProServer::SourceHydra::dbi->new();

=head1 SUBROUTINES/METHODS

=head2 sources : DBI sources

  Effectively returns the results of a SHOW TABLES LIKE '$basename%'
  query. In Oracle I guess this would need changing to table_name from
  all_tables where like '$basename%' or something.

  my @sources = $dbihydra->sources();

  $basename comes from $self->config->{'basename'};

  This routine caches results for $CACHE_TIMEOUT as show tables can be
  slow for a few thousand sources.

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

  [mysimplehydra]
  adaptor   = simpledb           # SourceAdaptor to clone
  hydra     = dbi                # Hydra implementation to use
  transport = dbi
  basename  = hydra              # dbi: basename for db tables containing servable data
  dbname    = proserver
  dbhost    = mysql.example.com
  dbuser    = proserverro
  dbpass    = topsecret

=head1 DEPENDENCIES

Bio::Das::ProServer::SourceHydra

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=cut
