#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2003-05-27
# $Id: file.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# $Source$
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/Transport/file.pm $
#
# Transport layer for file-based storage (slow)
#
package Bio::Das::ProServer::SourceAdaptor::Transport::file;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use File::stat;
use English qw(-no_match_vars);
use Carp;

our $VERSION  = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

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
  local $RS = "\n";
  my $debug = $self->{'debug'};
  my $fh    = $self->_fh();
  seek $fh, 0, 0;

  $debug and print {*STDERR} "Transport::file::query was $query\n";
  my ($field, $cmp, $value) = split /\s/mx, $query;
  $field   =~ s/^field//mx;
  $value   =~ s/^[\"\'](.*?)[\"\']$/$1/mx;
  $value   =~ s/%/.*?/mxg;
  $cmp     = lc $cmp;
  my $ref  = [];

  while(my $line = <$fh>) {
    chomp $line;
    my @parts = split /\t/mx, $line;

    my $flag = 0;
    if($cmp eq q(=) && $parts[$field] eq $value) {
      $flag = 1;

    } elsif($cmp eq 'lceq' && lc $parts[$field] eq lc $value) {
      $flag = 1;

    } elsif($cmp eq 'like' && $parts[$field] =~ /^$value$/mxi) {
      $flag = 1;
    }

    if($flag) {
      push @{$ref}, \@parts;
      if($self->config->{'unique'}) {
	last;
      }
    }
  }
  return $ref;
}

sub last_modified {
  my $self = shift;
  return stat($self->_fh())->mtime;
}

sub DESTROY {
  my $self = shift;
  if($self->{'fh'}) {
    close $self->{'fh'} or carp 'Error closing fh';;
  }
  return;
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::file

=head1 VERSION

$Revision: 453 $

=head1 SYNOPSIS

=head1 DESCRIPTION

A simple data transport for tab-separated files. Access is via the 'query' method.
Expects a tab-separated file with no header line.

=head1 SUBROUTINES/METHODS

=head2 query - Execute a basic query against a text file

 assume text files are tab delimited (?)

 queries are of the form:

 $filetransport->query(qq(field1 = 'value'));
 $filetransport->query(qq(field1 lceq 'value'));
 $filetransport->query(qq(field3 like '%value%'));

 compound queries not (yet) supported

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

=head1 DEPENDENCIES

=over

=item L<File::stat>

=item L<Bio::Das::ProServer::SourceAdaptor::Transport::generic>

=back

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

Compound queries are not supported.

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2008 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
