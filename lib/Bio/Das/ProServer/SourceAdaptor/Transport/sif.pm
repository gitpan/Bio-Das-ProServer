#########
# Author:        Andy Jenkinson
# Created:       2008-02-01
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $ $xuthor$
# Id:            $Id: sif.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source$
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/Transport/sif.pm $
#
# Transport implementation for Simple Interaction Format files.
#
package Bio::Das::ProServer::SourceAdaptor::Transport::sif;

use strict;
use warnings;
use Carp;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::file);

our $VERSION = do { my ($v) = (q$LastChangedRevision: 453 $ =~ /\d+/mxg); $v; };

# Access to the transport is via this method (see POD)
sub query {
  my ($self, $q1, $q2, $q3) = @_;
  $q1 || return []; # No query
  if (ref $q1 && ref $q1 eq 'ARRAY') {
    ($q1, $q2, $q3) = @{$q1};
  }
  $q3 && return []; # SIF has only binary interactions
  my $fh    = $self->_fh();
  my $start = tell $fh;
  my $interactors = {};
  my $interactions = {};

  my $sep;
  while(<$fh>) {
    chomp;
    # if the file contains tabs, tab is separator
    $sep ||= /\t/mx ? '\t' : '\s';  ## no critic (Perl::Critic::Policy::ValuesAndExpressions::RequireInterpolationOfMetachars)

    # If looking for 2 interactors, one -has- to be the source node
    if ($q2) {
      if (/^$q1$sep+([^$sep]+$sep+)+$q2($sep|\Z)/mx || /^$q2$sep+([^$sep]+$sep+)+$q1($sep|\Z)/mx) {
        $self->_add_interaction($q1, $q2, $interactors, $interactions);
        last;
      }
    }

    # Different result depending on whether the 'hit' is the first node
    else {
      my ($source, undef, @targets) = split /$sep+/mx;
      if ($source eq $q1) {
        for my $t (@targets) {
          $self->_add_interaction($q1, $t, $interactors, $interactions);
        }
      }
      elsif (scalar grep { /^$q1$/mx } @targets) {
        $self->_add_interaction($source, $q1, $interactors, $interactions);
      }
    }
  }

  # Reset the filehandle to what it was previously (not necessarily the start..)
  seek $fh, $start, 0;

  $interactors  = [values %{$interactors}];
  $interactions = [values %{$interactions}];
  $self->_add_attributes($interactors, $interactions);

  return {
          'interactors'  => $interactors,  ## no critic
          'interactions' => $interactions,
         };
}

sub _add_interaction {
  my ($self, $x, $y, $interactors, $interactions) = @_;
  # sort lexographically (interactions are unique)
  if (($x cmp $y) > 0) {
    ($x, $y) = ($y, $x);
  }
  $self->{'debug'} && carp "SIF transport found interaction $x-$y";
  $interactors->{$x} ||= {'id'=>$x};
  $interactors->{$y} ||= {'id'=>$y};
  $interactions->{"$x-$y"} ||= {
    'name'         => "$x-$y",
    'participants' => [{'id'=>$x},{'id'=>$y}],
  };
  return;
}

sub _add_attributes {
  my ($self, $interactors, $interactions) = @_;

  my @interactor_files  = grep {$_->{'type'} eq 'interactor'}  $self->_att_fh();
  my @interaction_files = grep {$_->{'type'} eq 'interaction'} $self->_att_fh();

  for my $interactor (@{$interactors}) {
    for my $file (@interactor_files) {
      my $fh = $file->{'fh'};
      my $start = tell $fh;
      while (<$fh>) {
        chomp;
        my ($id, $value) = split /\s*=\s*/mx;
        if ($id eq $interactor->{'id'}) {
          $self->{'debug'} && carp "SIF transport found $file->{property} property for interactor $id";
          push @{ $interactor->{'details'} }, {
            'property' =>$file->{'property'},
            'value'    =>$value,
          };
          last;
        }
      }
      seek $fh, $start, 0;
    }
  }

  for my $interaction (@{$interactions}) {
    for my $file (@interaction_files) {
      my $fh = $file->{'fh'};
      my $sep = $file->{'sep'};
      my $start = tell $fh;
      while (<$fh>) {
        chomp;
        my ($x, $y, $value) = /^([^$sep]+)$sep+[^$sep]+$sep+([^$sep]+)\s*=\s*(.+)/mx;
        if (($x cmp $y) > 0) {
          ($x, $y) = ($y, $x);
        }
        if ($interaction->{'name'} eq "$x-$y") {
          $self->{'debug'} && carp "SIF transport found $file->{property} property for interaction $x-$y";
          push @{ $interaction->{'details'} }, {
            'property' => $file->{'property'},
            'value'    => $value,
          };
          last;
        }
      }
      seek $fh, $start, 0;
    }
  }

  return;
}

sub _att_fh {
  my $self = shift;

  if (!exists $self->{'fh_att'}) {
    $self->{'fh_att'} = [];
    for my $fn (split /\s*[;,]\s*/mx, $self->config->{'attributes'}||q()) {
      my $fh;
      open $fh, '<', $fn or croak qq(Could not open $fn); ## no critic (Perl::Critic::Policy::InputOutput::RequireBriefOpen)
      my $property = <$fh>;
      chomp $property;
      my $start = tell $fh;
      my $line = <$fh>;
      my $sep = $line =~ m/\t/mx ? '\t' : '\s'; ## no critic (Perl::Critic::Policy::ValuesAndExpressions::RequireInterpolationOfMetachars)
      my $type = $line =~ /^[^$sep]+$sep+[^$sep]+$sep+[^$sep]+\s*=/mx ? 'interaction' : 'interactor';
      seek $fh, $start, 0;
      push @{ $self->{'fh_att'} }, {'fh'=>$fh,'type'=>$type,'property'=>$property,'sep'=>$sep};
    }
  }
  return wantarray ? @{ $self->{'fh_att'} } : $self->{'fh_att'};
}

sub DESTROY {
  my $self = shift;
  my @filehandles = ($self->{'fh'}, map {$_->{'fh'}} @{ $self->{'fh_att'}||[] });
  for my $fh (@filehandles) {
    $fh && close $fh;
  }
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::sif

=head1 VERSION

$LastChangedRevision: 453 $

=head1 SYNOPSIS

my $hInteractions = $oTransport->query('interactorA');
my $hInteractions = $oTransport->query('interactorA', 'interactorB');

=head1 DESCRIPTION

A data transport exposing interactions stored in a SIF file, along with
attributes stored in Cytoscape attribute files. Access is via the 'query' method.

=head1 FILE FORMAT

Each line of a Simple Interaction Format (SIF) file describes one or more binary
interactions, and takes the form:
  nodeA lineType nodeB [nodeC ...]

This example describes a protein-protein interaction between interactorA and interactorB:
  interactorA pp interactorB

This example describes three separate interactions, each involving interactorA:
  interactorA pp interactorB interactorC interactor D

Node attribute files may be used to add DAS 'detail' elements to interactors:
  description
  interactorA = An example interactor
  interactorB = Another example of an interactor
  ...

Edge attribute files may be used to add DAS 'detail' elements to interactions:
  score
  interactorA pp interactorB = 2.43
  interactorX pp interactorY = 5.1
  ...

=head1 CONFIGURATION AND ENVIRONMENT

Configured as part of each source's ProServer 2 INI file:

  [mysif]
  ... source configuration ...
  transport  = sif
  filename   = /data/interactions.sif
  attributes = /data/node-attribute.noa ; /data/edge-attributes.eda

=head1 SUBROUTINES/METHODS

=head2 query : Retrieves interactions for one or two interactors

  Retrieves interactions involving interactorA:
  $hInteractions = $oTransport->query('interactorA');
  
  Retrieves an interaction involving both interactorA and interactorB:
  $hInteractions = $oTransport->query('interactorA', 'interactorB');
  
  The returned hash is of the structure expected by ProServer.

=head2 DESTROY : object destructor - disconnect filehandles

  Generally not directly invoked, but if you really want to:

  $transport->DESTROY();

=head1 DIAGNOSTICS

Run ProServer with the -debug flag.

=head1 SEE ALSO

=over

=item L<http://www.cytoscape.org/cgi-bin/moin.cgi/Cytoscape_User_Manual/Network_Formats> Cytoscape - SIF

=item L<http://www.cytoscape.org/cgi-bin/moin.cgi/Cytoscape_User_Manual/Attributes> Cytoscape - Attributes

=back

=head1 DEPENDENCIES

=over

=item L<Carp>

=item L<Bio::Das::ProServer::SourceAdaptor::Transport::file>

=back

=head1 BUGS AND LIMITATIONS

The Simple Interaction Format is very simple, and therefore only supports a
limited range of DAS annotation details. It also only handles binary
interactions (i.e. those with exactly two interactors).

=head1 INCOMPATIBILITIES

None reported.

=head1 AUTHOR

Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 EMBL-EBI

=cut