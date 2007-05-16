#########
# wgetz.pm
# A ProServer transport module for wgetz (SRS web access)
#
# Andreas Kahari, andreas.kahari@ebi.ac.uk
#
package Bio::Das::ProServer::SourceAdaptor::Transport::wgetz;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);
use LWP::UserAgent;
use Carp;

our $VERSION = do { my @r = (q$Revision: 2.51 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub _useragent {
  # Caching an LWP::UserAgent instance within the current
  # object.

  my $self = shift;

  if (!defined $self->{_useragent}) {
    $self->{_useragent} = new LWP::UserAgent(
					     env_proxy	=> 1,
					     keep_alive	=> 1,
					     timeout	=> 30
					    );
  }

  return $self->{_useragent};
}

sub init {
  my $self = shift;
  $self->_useragent();
}

sub query {
  my $self   = shift;
  my $swgetz = $self->config->{wgetz} || 'http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz';
  my $query  = my $squery = join '+', @_;

  # Remove characters not allowed in transport.
  $swgetz =~ s/[^\w.\/:-]//mx;
  # Remove characters not allowed in query.
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

$Revision: 2.51 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head2 init

=head2 query

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Andreas Kahari, <andreas.kahari@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

=cut
