#########
# Author:        ak
# Maintainer:    $Author: andyjenkinson $
# Created:       2004
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $
# Id:            $Id: wgetz.pm 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source$
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/lib/Bio/Das/ProServer/SourceAdaptor/Transport/wgetz.pm $
#
package Bio::Das::ProServer::SourceAdaptor::Transport::wgetz;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use LWP::UserAgent;
use Carp;

our $VERSION = do { my @r = (q$Revision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub _useragent {
  # Caching an LWP::UserAgent instance within the current
  # object.

  my $self = shift;

  if (!defined $self->{_useragent}) {
    $self->{_useragent} = LWP::UserAgent->new(
					      env_proxy  => 1,
					      keep_alive => 1,
					      timeout    => 30
					     );
  }

  return $self->{_useragent};
}

sub init {
  my $self = shift;
  return $self->_useragent();
}

sub query {
  my ($self, @args) = @_;
  my $swgetz = $self->config->{wgetz} || 'http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz';
  my $query  = my $squery = join q(+), @args;

  #########
  # Remove characters not allowed in transport.
  #
  $swgetz =~ s/[^\w.\/:-]//mx;

  #########
  # Remove characters not allowed in query.
  #
  $squery =~ s/[^\w[\](){}.><:'"\ |+-]//mx;

  if ($squery ne $query) {
    carp "Detainted '$squery' != '$query'";
  }

  my $reply = $self->_useragent()->get("$swgetz?$squery+-ascii");

  if (!$reply->is_success()) {
    carp "wgetz request failed: $swgetz?$squery+-ascii\n";
  }

  return $reply->content();
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::Transport::wgetz - A ProServer transport module for wgetz (SRS web access)

=head1 VERSION

$LastChangedRevision: 453 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 _useragent

=head2 init

=head2 query

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

Bio::Das::ProServer::SourceAdaptor::Transport::generic
LWP::UserAgent
Carp

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andreas Kahari, <andreas.kahari@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
