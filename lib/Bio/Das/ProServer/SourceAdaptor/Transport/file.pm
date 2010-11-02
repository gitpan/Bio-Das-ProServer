#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2003-05-27
# $Id: file.pm 567 2009-01-12 16:10:48Z andyjenkinson $
# $Source$
# $HeadURL: https://proserver.svn.sourceforge.net/svnroot/proserver/tags/spec-1.53/lib/Bio/Das/ProServer/SourceAdaptor/Transport/file.pm $
#
# Transport layer for file-based storage (slow)
#
package Bio::Das::ProServer::SourceAdaptor::Transport::file;

use strict;
use warnings;

use File::stat;
use English qw(-no_match_vars);
use Carp;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);

our $VERSION  = do { my ($v) = (q$Revision: 567 $ =~ /\d+/mxg); $v; };

sub _fh {
  my $self = shift;

  if(!$self->{'fh'}) {
    my $fn = $self->{'filename'} || $self->config->{'filename'};
    open $self->{'fh'}, q(<), $fn or croak qq(Could not open $fn);
  }
  return $self->{'fh'};
}

sub query {
  my ($self, $query) = @_;

  $self->{'debug'} and carp "Transport::file::query was $query\n";
  my @queries = ();
  for (split /\s(?:AND|&&)\s/i, $query) {
    my ($field, $cmp, $value) = split /\s/mx, $_;
    $field   =~ s/^field//mx;
    $value   =~ s/^[\"\'](.*?)[\"\']$/$1/mx;
    $value   =~ s/%/.*?/mxg;
    $cmp     = lc $cmp;

    if ($cmp eq '=') {
      push @queries, sub { $_[$field] eq $value };
    } elsif ($cmp eq 'lceq') {
      push @queries, sub { lc $_[$field] eq lc $value };
    } elsif ($cmp eq 'like') {
      push @queries, sub { $_[$field] =~ /^$value$/mxi };
    } elsif ($cmp eq '>=') {
      push @queries, sub { return $_[$field] >= $value ? 1 : 0 };
    } elsif ($cmp eq '>') {
      push @queries, sub { $_[$field] > $value };
    } elsif ($cmp eq '<=') {
      push @queries, sub { return $_[$field] <= $value ? 1 : 0 };
    } elsif ($cmp eq '<') {
      push @queries, sub { $_[$field] < $value };
    } else {
      carp "Unrecognised query: $_\n";
    }
  }

  return $self->config->{'cache'} && $self->config->{'cache'} ne 'no' ?
    $self->_query_mem(@queries) :
    $self->_query_fh(@queries);
}

sub _query_mem {
  my ( $self, @predicates ) = @_;
  $self->{'debug'} && carp "Querying against memory cache";
  my $ref = [];
  LINE: for my $parts (@{ $self->_contents() }) {
    for my $predicate (@predicates) {
      &$predicate( @{ $parts } ) || next LINE;
    }

    push @{$ref}, $parts;
    if($self->config->{'unique'}) {
      last;
    }
  }
  return $ref;
}

sub _query_fh {
  my ( $self, @predicates ) = @_;

  $self->{'debug'} && carp "Querying against file";
  local $RS = "\n";
  my $fh    = $self->_fh();
  seek $fh, 0, 0;

  my $ref = [];
  LINE: while(my $line = <$fh>) {
    chomp $line;
    $line || next;
    my @parts = split /\t/mx, $line;

    for my $predicate (@predicates) {
      &$predicate( @parts ) || next LINE;
    }

    push @{$ref}, \@parts;
    if($self->config->{'unique'}) {
      last;
    }
  }
  return $ref;
}

sub _contents {
  my $self = shift;

  if (!exists $self->{'_contents'}) {
    local $RS = "\n";
    my $fh    = $self->_fh();
    seek $fh, 0, 0;

    my $ref = [];
    while(my $line = <$fh>) {
      chomp $line;
      $line || next;
      my @parts = split /\t/mx, $line;
      push @{$ref}, \@parts;
    }
    $self->{'_contents'} = $ref;
    $self->{'_modified'} = stat($fh)->mtime; # Set the modified time
  }

  return $self->{'_contents'};
}

sub last_modified {
  my $self = shift;
  # If the file was cached, use the time from when it was loaded
  if ($self->{'_modified'}) {
    return $self->{'_modified'};
  }
  # Otherwise check it explicitly
  return stat($self->_fh())->mtime;
}

sub DESTROY {
  my $self = shift;
  if($self->{'fh'}) {
    close $self->{'fh'} or carp 'Error closing fh';
  }
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::file

=head1 VERSION

$Revision: 567 $

=head1 SYNOPSIS

=head1 DESCRIPTION

A simple data transport for tab-separated files. Access is via the 'query' method.
Expects a tab-separated file with no header line.

Can optionally cache the file contents upon first usage. This may improve
subsequence response speed at the expense of memory footprint.

=head1 SUBROUTINES/METHODS

=head2 query - Execute a basic query against a text file

 Queries are of the form:

 $filetransport->query(qq(field1 = 'value'));
 $filetransport->query(qq(field1 lceq 'value'));
 $filetransport->query(qq(field3 like '%value%'));
 $filetransport->query(qq(field0 = 'value' && field1 = 'value'));
 $filetransport->query(qq(field0 = 'value' and field1 = 'value'));
 $filetransport->query(qq(field0 = 'value' and field1 = 'value' and field2 = 'value'));

 "OR" compound queries not (yet) supported

=head2 last_modified - machine time of last data change

  $dbitransport->last_modified();

=head2 DESTROY - object destructor - disconnect filehandle

  Generally not directly invoked, but if you really want to - 

  $filetransport->DESTROY();

=head1 DIAGNOSTICS

Run ProServer with the -debug flag.

=head1 CONFIGURATION AND ENVIRONMENT

Configured as part of each source's ProServer 2 INI file:

  [myfile]
  ... source configuration ...
  transport = file
  filename  = /data/features.tsv
  unique    = 1 # optional
  cache     = 1 # optional

=head1 DEPENDENCIES

=over

=item L<File::stat>

=item L<Bio::Das::ProServer::SourceAdaptor::Transport::generic>

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Only AND compound queries are supported.

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk> and Andy Jenkinson <aj@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 The Sanger Institute and EMBL-EBI

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
