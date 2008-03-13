#########
# Author:        jc3
# Maintainer:    $Author: andyjenkinson $
# Created:       2005-11-21
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $
# Id:            $Id: csv.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source$
#
package Bio::Das::ProServer::SourceAdaptor::Transport::csv;

use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::dbi);

our $VERSION = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub dbh {
  my $self    = shift;
  my $dbname  = $self->config->{path} || q(/var/tmp/);
  my $csv_sep = $self->config->{csv_sep_char} || "\t";
  my $eol     = "\n";
  my $table   = $self->config->{filename} || 'default';
  my $dsn     = qq(DBI:CSV:f_dir=$dbname;csv_sep_char=$csv_sep;csv_eol=$eol;);

  $self->{dbh} ||= DBI->connect($dsn);
  $self->{dbh}->{RaiseError} = 1;

  if($self->config->{col_names}) {
    my $cols = [split /:/mx, $self->config->{col_names}];

    if (scalar @{$cols}) {
      $self->{dbh}->{csv_tables}->{$table} = {
					      col_names => $cols,
					     };
    }
  }

  return $self->{dbh};
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::csv - Comma-separated-values transport layer

=head1 VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 dbh - DBI:CSV handle

  Overrides Transport::dbi

  my $dbh = $csvtransport->dbh();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Jody Clements <jc3@sanger.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2005 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
