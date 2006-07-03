#########
# Author: rmp
# Maintainer: rmp
# Created: 2004-02-03
# Last Modified: 2004-02-03
# Builds DAS features from Protein-Protein Interaction Database
#
package Bio::Das::ProServer::SourceAdaptor::ppid;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use vars qw(@ISA);
use Bio::Das::ProServer::SourceAdaptor;
@ISA = qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features' => '1.0',
			    };
}

sub length { 0; }

sub build_features {
  my ($self, $opts) = @_;
  my $spid  = $opts->{'segment'};
  my $ppid  = "";

  if($opts->{'segment'} =~ /^A\d{4}$/) {
    #########
    # entry with a PPID id, e.g. A0002
    #
    $ppid = $spid;

    my $qppid = $self->transport->dbh->quote($ppid);
    my $query = qq(SELECT swprotid
                   FROM   swprotids
                   WHERE  ppid = $qppid);

    if($self->{'dsn'} =~ /hydra/) {
      my ($species)   = $self->{'dsn'} =~ /^.*_(\S+)$/;
      $query         .= sprintf(" AND species=%s", $self->transport->dbh->quote($species));
    }

    my $ref   = $self->transport->query($query);
    $spid = $ref->[0]->{'swprotid'};

  } else {
    #########
    # entry with something else - let's try mapping a swissprot id
    #
    my $qspid = $self->transport->dbh->quote($opts->{'segment'});
    my $ref   = $self->transport->query(qq(SELECT ppid
                                           FROM   swprotids
                                           WHERE  swprotid = $qspid));
    $ppid = $ref->[0]->{'ppid'};
  }

  my $qppid = $self->transport->dbh->quote($ppid);

  #########
  # pull mainname / label for this id
  #
  my $ref   = $self->transport->query(qq(SELECT mainname, note
                                         FROM   proteins
                                         WHERE  ppid=$qppid));
  my $label = $ref->[0]->{'mainname'};
  $label    =~ s/[\n\r]/ /smg;
  my $description = $ref->[0]->{'note'};
  $description    =~ s/[\n\r]/ /smg;



  my $query = qq(SELECT s.swprotid, b.ppid_2 AS ppid, p.mainname
		 FROM   bind b,swprotids s, proteins p
		 WHERE  b.ppid_1 = $qppid
                 AND    b.ppid_2 = s.ppid
                 AND    p.ppid   = b.ppid_2);
  if($self->{'dsn'} =~ /hydra/) {
    my ($species) = $self->{'dsn'} =~ /^.*_(\S+)$/;
    $query .= sprintf(" AND s.species=%s", $self->transport->dbh->quote($species));
  }

  $ref = $self->transport->query($query);
  my $str = qq(@{[map {
      my $note = $_->{'mainname'} || "";
      $note    =~ s/\s+/_/smg;
      $note  ||= $_->{'swprotid'};
      sprintf(" %s%s%s ", $note, ($_->{'swprotid'}?":navigation://":""), $_->{'swprotid'}||"");
  } @{$ref}]});


  my @features = ({
		   'id'     => $opts->{'segment'},
		   'label'  => $ppid,
		   'type'   => 'ppi',
		   'method' => 'ppi',
		   'note'   => qq(The <A href="http://www.anc.ed.ac.uk/mscs/PPID/">PPID Database</a> records that the product of gene $label interacts with products of the following genes: $str),
		   'link'   => qq(http://www.sanger.ac.uk/perl/ontologybrowser/browser?id=$ppid),
		  });

  if($description) {
    push @features, {
		     'id'     => $opts->{'segment'},
		     'label'  => $label,
		     'type'   => "description",
		     'method' => "description",
		     'note'   => $description,
		    };
  }
  return @features;
}

1;
