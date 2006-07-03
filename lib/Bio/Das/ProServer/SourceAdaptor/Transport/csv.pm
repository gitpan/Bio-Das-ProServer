#########
# Author:        jc3
# Maintainer:    $Author: rmp $
# Created:       2005-11-21
# Last Modified: $Date: 2006/07/03 10:05:07 $
#
# csv transport layer
#
package Bio::Das::ProServer::SourceAdaptor::Transport::csv;

=head1 AUTHOR

Jody Clements <jc3@sanger.ac.uk>.

Copyright (c) 2005 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

use strict;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::dbi);

=head2 : dbh : DBI:CSV handle

  Overrides Transport::dbi

  my $dbh = $csvtransport->dbh();

=cut
sub dbh {
  my $self     = shift;
  my $dbname   = $self->config->{'path'} || "/var/tmp/";
  my $csv_sep  = $self->config->{'csv_sep_char'} || "\t";
  my $eol      = "\n";
  my $table    = $self->config->{'filename'} || "default";

  
  my $dsn = qq(DBI:CSV:f_dir=$dbname;csv_sep_char=$csv_sep;csv_eol=$eol;);
  
  $self->{'dbh'} ||= DBI->connect($dsn);
  $self->{'dbh'}->{'RaiseError'} = 1;
  if($self->config->{'col_names'}){
    my @cols = split ":", $self->config->{'col_names'};
    
    $self->{'dbh'}->{'csv_tables'}->{$table} = {
                  'col_names' => \@cols,
                } if (@cols);
  }
  return $self->{'dbh'};
}

1;
