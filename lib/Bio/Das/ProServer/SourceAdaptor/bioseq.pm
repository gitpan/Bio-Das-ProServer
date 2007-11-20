#########
# Author:        Andreas Kahari, andreas.kahari@ebi.ac.uk
# Maintainer:    $Author: rmp $
# Created:       ?
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Id:            $Id: bioseq.pm,v 2.70 2007/11/20 20:12:21 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor/bioseq.pm,v $
# $HeadURL$
# 
package Bio::Das::ProServer::SourceAdaptor::bioseq;
use strict;
use warnings;

use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self = shift;
  $self->{capabilities} = {
			   'features'  => '1.0',
			   'dna'       => '1.0'
			  };
}

sub length {
  my ($self, $id) = @_;
  my $seq = $self->transport->query($id);

  if (defined $seq) {
    return $seq->length();
  }
  return 0;
}

sub build_features {
  my ($self,$opts) = @_;
  my $seq = $self->transport->query($opts->{segment});

  if (!defined $seq) {
    return ();
  }

  my @features;
  for my $feature ($seq->get_SeqFeatures()) {
    push @features, {
		     type   => $feature->primary_tag(),
		     start  => $feature->start(),
		     end    => $feature->end(),
		     method => $feature->source_tag(),
		     id	    => $feature->display_name() ||
		               sprintf q(%s/%s:%d,%d),
				       $seq->display_name(), $feature->primary_tag(),
				       $feature->start(), $feature->end(),
		     ori    => $feature->strand(),
		    };
  }

  return @features;
}

sub sequence {
  my ($self, $opts) = @_;
  my $seq = $self->transport->query($opts->{segment});

  if (!defined $seq) {
    return { seq => q(), moltype => q() };
  }

  return {
	  seq     => $seq->seq()      || q(),
	  moltype => $seq->alphabet() || q(),
	 };
}

1;

__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::bioseq - A ProServer source
adaptor for converting Bio::Seq objects into DAS features.  See also
"Transport/bioseqio.pm".

=head1 VERSION

$Revision: 2.70 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andreas Kahari, andreas.kahari@ebi.ac.uk

=head1 LICENSE AND COPYRIGHT
