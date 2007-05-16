#########
# Author:        dkj
# Maintainer:    dkj
# Created:       2005-11-15
# Last Modified: $Date: 2007/03/09 14:23:56 $
# Id:            $Id: simplescoreh_db.pm,v 2.51 2007/03/09 14:23:56 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceHydra/simplescoreh_db.pm,v $
# $HeadURL$
#
# hydra broker for simplescore_db databases
#
package Bio::Das::ProServer::SourceHydra::simplescoreh_db;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceHydra);

our $VERSION = do { my @r = (q$Revision: 2.51 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub sources {
  my $self = shift;
  my $dsn  = $self->{'dsn'};

  return map {$dsn.$_}
         map {values %{$_}}
         @{$self->transport->query(q(SELECT DISTINCT experiment_id FROM data))};
}

1;

__END__

=head1 NAME

Bio::Das::ProServer::SourceHydra::simplescoreh_db - hydra broker for simplescore_db databases

=head1 VERSION

$Revision: 2.51 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 sources : Array of sources to clone based on experiment_id

 my @sourcenames = $oHydra->sources();

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

David Jackson <dj3@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut
