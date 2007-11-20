package Bio::Das::ProServer::SourceAdaptor::simple_interaction;

use strict;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self = shift;
  $self->{'capabilities'}{'interaction'} = '1.0';
}

sub build_interaction {
  my ($self, $opts) = @_;
  
  my %interactors = ();
  
  my $regex = '(\w*,)*'.join ('(,\w*)*', sort { $a cmp $b } @{ $opts->{'interactors'} }).'(,\w*)*';
  my $rows = $self->transport->query("field0 like $regex");
  my @interactions = ();
  INTERACTION: for my $row (@$rows) {
    
    my @participants = split /,/, shift @$row;
    
    my $interaction = $self->_build_interaction($row);
    my %details = map { $_->{'property'} => $_->{'value'} } @{$interaction->{'details'}};
    
    # Filter for interactions with requested details
    while (my ($key, $val) = each %{ $opts->{'details'} }) {
      exists $details{$key} || next INTERACTION;
      !defined $val || $val eq $details{$key} || next INTERACTION;
    }
    
    for my $participant (@participants) {
      my $interactor_row = $self->transport('interactors')->query("field0 = $participant")->[0];
      $interactors{$participant} ||= $self->_build_interactor($interactor_row);
      push @{ $interaction->{'participants'} }, {
        'id' => $participant,
      };
    }
    
    push @interactions, $interaction;
  }
  
  return {
    'interactors'  => [values %interactors],
    'interactions' => \@interactions,
  };
}

sub _build_interaction {
  my ($self, $row) = @_;
  
  my %interaction = ();
  for (qw(label dbSource dbSourceCvId dbVersion dbAccession)) {
    $interaction{$_} = shift @$row;
  }
  
  while (@$row) {
    my %details = ();
    for (qw(property value propertyCvId valueCvId)) {
      $details{$_} = shift @$row;
    }
    push @{ $interaction{'details'} }, \%details;
  }
  
  return \%interaction;
}
  
sub _build_interactor {
  my ($self, $row) = @_;
  
  my %interactor = ();
  for (qw(id label dbSource dbSourceCvId dbVersion dbAccession dbCoordSys sequence)) {
    $interactor{$_} = shift @$row;
  }
  
  while (@$row) {
    my %details = ();
    for (qw(property value propertyCvId valueCvId start end startStatus endStatus startStatusCvId endStatusCvId)) {
      $details{$_} = shift @$row;
    }
    push @{ $interactor{'details'} }, \%details;
  }
  
  return \%interactor;
}

1;
__END__

=head1 NAME

  Bio::Das::ProServer::SourceAdaptor::simple_interaction

=head1 AUTHOR

  Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 DESCRIPTION

  Serves up interaction DAS responses, using a file-based transport.

=head1 CONFIGURATION

  [simple_interaction]
  adaptor               = simple_interaction
  state                 = on
  transport             = file
  filename              = /data/interactions.txt
  interactors.filename  = /data/interactors.txt
  coordinates           = MyCoordSys -> 001
  
  Tab-separated file formats:
  
  --interactors.txt--
  id	label	dbSource	dbSourceCvId	dbVersion	dbAccession	dbCoordSys	sequence	property	value	propertyCvId	valueCvId	start	end	startStatus	endStatus	startStatusCvId	endStatusCvId
  
  --interactions.txt--
  interactor,interactor,..(sorted)	label	dbSource	dbSourceCvId	dbVersion	dbAccession	property	value	propertyCvId	valueCvId

=head1 USAGE

  Interactions involving 001:
  <host>/das/<source>/interaction?interactor=001
  
  Interactions between 001 and 002
  <host>/das/<source>/interaction?interactor=001;interactor=002
  
  Interactions with some form of evidence:
  <host>/das/<source>/interaction?interactor=001;detail=property:evidence
  
  Interactions of a specific type:
  <host>/das/<source>/interaction?interactor=001;detail=property:type,value:foo

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