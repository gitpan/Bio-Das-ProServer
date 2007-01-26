#########
# Author:        rmp
# Maintainer:    rmp
# Created:       2003-05-20
# Last Modified: 2003-05-27
#
# Transport layer for file-based storage (slow)
#
package Bio::Das::ProServer::SourceAdaptor::Transport::file;

=head1 AUTHOR

Roger Pettett <rmp@sanger.ac.uk>.

Copyright (c) 2003 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);

our $VERSION  = do { my @r = (q$Revision: 2.50 $ =~ /\d+/g); sprintf '%d.'.'%03d' x $#r, @r };

sub _fh {
  my $self = shift;

  unless($self->{'fh'}) {
    my $fn = $self->{'filename'} || $self->config->{'filename'};
    open($self->{'fh'}, $fn) or die qq(Could not open $fn);
  }
  return $self->{'fh'};
}

=head2 query : Execute a basic query against a text file

 assume text files are tab delimited (?)

 queries are of the form:

 $filetransport->query(qq(field1 = 'value'));
 $filetransport->query(qq(field3 like '%value%'));

 compound queries not (yet) supported

=cut
sub query {
  local $/  = "\n";
  my $self  = shift;
  my $query = shift;
  my $debug = $self->{'debug'};
  my $fh    = $self->_fh();
  seek($fh, 0, 0);

  $debug and print STDERR "Transport::file::query was $query\n";
  my ($field, $cmp, $value) = split(/\s/, $query);
  $field   =~ s/^field//;
  $value   =~ s/^[\"\'](.*?)[\"\']$/$1/;
  $value   =~ s/%/.*?/g;
  $cmp     = lc($cmp);
  my $ref  = [];

  while(my $line = <$fh>) {
    chomp $line;
    my @parts = split("\t", $line);

    my $flag = 0;
    if($cmp eq '=') {
      $flag = 1 if($parts[$field] eq $value);

    } elsif($cmp eq 'lceq') {
      $flag = 1 if(lc($parts[$field]) eq lc($value));

    } elsif($cmp eq 'like') {
      $flag = 1 if($parts[$field] =~ /^$value$/i);
    }

    if($flag) {
      push @{$ref}, \@parts;
      last if($self->config->{'unique'});
    }
  }
  return $ref;
}

=head2 DESTROY : object destructor - disconnect filehandle

  Generally not directly invoked, but if you really want to - 

  $filetransport->DESTROY();

=cut
sub DESTROY {
  my $self = shift;
  close($self->{'fh'}) if($self->{'fh'});
}

1;
