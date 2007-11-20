package Bio::Das::ProServer::SourceAdaptor::simple_volmap;

use strict;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self = shift;
  $self->{'capabilities'} = { map { $_ => '1.0' } qw(volmap entry_points) };
}

sub length {
  my ($self, $segment) = @_;
  return $self->transport->query("field0 = $segment")->[0]->[1];
}

sub known_segments {
  my $self = shift;
  return  map { $_->[0] } @{ $self->transport->query('field0 like .*') };
}

sub build_volmap {
  my ($self, $segment) = @_;
  my $row = $self->transport->query("field0 = $segment")->[0];
  my %volmap = ();
  for (qw(id _tmp class type version link linktxt)) {
    $volmap{$_} = shift @$row;
  }
  $volmap{'note'} = [@$row];
  return \%volmap;
}

1;
__END__

=head1 NAME

  Bio::Das::ProServer::SourceAdaptor::simple_volmap

=head1 AUTHOR

  Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 DESCRIPTION

  Serves up volume map DAS responses, using a file-based transport.

=head1 CONFIGURATION

  [simple_volmap]
  adaptor               = simple_volmap
  state                 = on
  transport             = file
  filename              = /data/volmap.txt
  coordinates           = MyCoordSys -> Vol01
  
  Tab-separated file formats:
  
  --volmap.txt--
  id	length	class	type	version	link	linktxt

=head1 USAGE

  Volume map for Vol01:
  <host>/das/<source>/volmap?query=volumeID

=head1 DEPENDENCIES

=over

=item L<Bio::Das::ProServer::SourceAdaptor>

=back

=head1 INCOMPATIBILITIES

None reported

=head1 BUGS AND LIMITATIONS

None reported

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 EMBL-EBI

=cut