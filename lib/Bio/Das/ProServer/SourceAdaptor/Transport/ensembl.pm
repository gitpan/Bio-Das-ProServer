#########
# Author:        aj
# Maintainer:    $Author: andyjenkinson $
# Created:       2006
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $
# Id:            $Id: ensembl.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source$
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/Transport/ensembl.pm $
#
package Bio::Das::ProServer::SourceAdaptor::Transport::ensembl;
use strict;
use warnings;
use Carp;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

our $VERSION  = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my ($self) = @_;
  $self->{'_species'} = $self->config->{'species'};
  $self->{'_group'}   = $self->config->{'group'};
  $self->_apply_override;
  $self->_load_registry;
  return;
}

sub _load_registry {
  my ($self) = @_;
  Bio::EnsEMBL::Registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org',
    -user => 'anonymous',
    -verbose => $self->{'debug'} );
  Bio::EnsEMBL::Registry->set_disconnect_when_inactive();
  return;
}

sub _apply_override {
  my ($self) = @_;
  my $dbname = $self->config->{'dbname'};

  if ($dbname) {
    $self->{'debug'} && carp "Overriding database with $dbname\n";
    my ($species, $group) = $dbname =~ m/([a-z_]+)_([a-z]+)_\d+/mx;
    $species || croak "Unknown database to override: $dbname";
    if ($species  eq 'ensembl') {
      $species = 'multi';
    }
    $self->{'_species'} = $species;
    $self->{'_group'}   = $group;

    # Creating a new connection will add it to the registry.
    my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
      -host    => $self->config->{'host'}     || 'localhost',
      -port    => $self->config->{'port'}     || '3306',
      -user    => $self->config->{'username'} || 'ensro',
      -pass    => $self->config->{'password'},
      -dbname  => $dbname,
      -species => $species,
      -group   => $group,
    );
  }
  return;
}

sub adaptor {
  my ($self, $species, $group) = @_;
  $species ||= $self->{'_species'} || 'human';
  $group   ||= $self->{'_group'}   || 'core';
  my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor( $species, $group );
  $self->{'debug'} && carp "Got adaptor for $species / $group (".$dba->dbc->dbname.")\n";
  return $dba;
}

sub gene_adaptor {
  my ($self, $species, $group) = @_;
  return $self->adaptor($species, $group)->get_GeneAdaptor();
}

sub slice_adaptor {
  my ($self, $species, $group) = @_;
  return $self->adaptor($species, $group)->get_SliceAdaptor();
}

sub chromosome_by_region { ## no critic
  my ($self, $chr, $start, $end, $species, $group) = @_;
  return $self->slice_adaptor($species, $group)->fetch_by_region('chromosome', $chr, $start, $end);
}

sub chromosomes {
  my ($self, $species, $group) = @_;
  return $self->slice_adaptor($species, $group)->fetch_all('chromosome');
}

sub gene_by_id {
  my ($self, $id, $species, $group) = @_;
  return $self->gene_adaptor($species, $group)->fetch_by_stable_id($id);
}

sub genes {
  my ($self, $species, $group) = @_;
  return $self->gene_adaptor($species, $group)->fetch_all();
}

sub version {
  my ($self) = @_;
  return Bio::EnsEMBL::Registry->software_version();
}

sub last_modified {
  my ($self) = @_;
  my $dbc = $self->adaptor()->dbc();
  my $sth = $dbc->prepare(q(SHOW TABLE STATUS));
  $sth->execute();
  my $server_text = [sort { $b cmp $a } ## no critic
                     keys %{ $sth->fetchall_hashref('Update_time') }
                    ]->[0]; # server local time
  $sth->finish();
  $sth = $dbc->prepare(q(SELECT UNIX_TIMESTAMP(?) as 'unix'));
  $sth->execute($server_text); # sec since epoch
  my $server_unix = $sth->fetchrow_arrayref()->[0];
  $sth->finish();
  return $server_unix;
}

sub disconnect {
  my $self = shift;
  Bio::EnsEMBL::Registry->disconnect_all();
  $self->{'debug'} and carp "$self performed disconnect\n";
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::ensembl

=head1 VERSION

$LastChangedRevision: 453 $

=head1 SYNOPSIS

A transport for using the Registry to retrieve Ensembl data.

=head1 DESCRIPTION

This class is a Transport that provides an interface to the Ensembl API. It uses
the Ensembl Resistry to determine the location of the appropriate databases,
and can be used in a species specific or cross-species manner. The main
advantage of using this Transport is that the registry automatically provides
access to the latest data available to the installed API.

=head1 SUBROUTINES/METHODS

=head2 init - Post-construction initialisation.

  $oTransport->init();
  
  Loads the registry from the Ensembl database, and applies a custom database
  override if specified.

=head2 adaptor - Gets an Ensembl adaptor.

  $oAdaptor = $oTransport->adaptor();
  $oAdaptor = $oTransport->adaptor('human', 'core');

  Arguments:
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    L<Bio::EnsEMBL::DBSQL::DBAdaptor>

=head2 slice_adaptor - Gets an Ensembl slice adaptor.
  
  $oAdaptor = $oTransport->slice_adaptor();
  $oAdaptor = $oTransport->slice_adaptor('human', 'core');

  Arguments:
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    L<Bio::EnsEMBL::DBSQL::SliceAdaptor>

=head2 gene_adaptor - Gets an Ensembl gene adaptor.
  
  $oAdaptor = $oTransport->gene_adaptor();
  $oAdaptor = $oTransport->gene_adaptor('human', 'core');

  Arguments:
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    L<Bio::EnsEMBL::DBSQL::GeneAdaptor>

=head2 chromosome_by_region - Gets a chromosome slice.

  $oSlice = $oTransport->chromosome_by_region('X');
  $oSlice = $oTransport->chromosome_by_region('X', 123453, 132424);
  $oSlice = $oTransport->chromosome_by_region('X', 123453, 132424, 'human', 'core');
  
  Arguments:
    chromosome #   (required)
    start          (optional)
    end            (optional)
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    L<Bio::EnsEMBL::Slice>

=head2 chromosomes - Gets all chromosomes.

  $aSlices = $oTransport->chromosomes();
  $aSlices = $oTransport->chromosomes('human', 'core');
  
  Arguments:
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    listref of L<Bio::EnsEMBL::Slice> objects

=head2 gene_by_id - Gets a gene.

  $oGene = $oTransport->gene_by_id('ENSG00000139618'); # BRCA2
  $oGene = $oTransport->gene_by_id('ENSG00000139618', 'human', 'core');
  
  Arguments:
    gene stable ID (required)
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    L<Bio::EnsEMBL::Gene>

=head2 genes - Gets all genes.

  $aGenes = $oTransport->genes();
  $aGenes = $oTransport->genes('human', 'core');
  
  Arguments:
    species        (optional, default configured in INI or 'human')
    database group (optional, default configured in INI or 'core')
  Returns:
    listref of L<Bio::EnsEMBL::Gene> objects

=head2 version - Gets the Ensembl API's release number.

  $sVersion = $oTransport->version();
  
=head2 last_modified - Gets a last modified date from the database.

  $sVersion = $oTransport->version();

=head2 disconnect - ProServer hook to disconnect all connected databases.

  $oTransport->disconnect();

=head1 CONFIGURATION AND ENVIRONMENT

Configured as part of each source's ProServer 2 INI file.

  The 'default database' is configured using these properties:
    species  (defaults to human)
    group    (defaults to core)

  A specific database may be overridden using these properties:
    dbname
    host     (defaults to localhost)
    port     (defaults to 3306)
    username (defaults to ensro)
    password

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=over

=item L<Carp>

=item L<Bio::Das::ProServer::SourceAdaptor::Transport::generic>

=item L<Bio::EnsEMBL::Registry>

=item L<Bio::EnsEMBL::DBSQL::DBAdaptor>

=back


=head1 INCOMPATIBILITIES

None reported

=head1 BUGS AND LIMITATIONS

None reported

=head1 REFERENCES

=over

=item L<http://www.ensembl.org/info/software/Pdoc/ensembl/> Ensembl API

=back

=head1 AUTHOR

Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 EMBL-EBI
