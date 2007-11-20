# Andreas Kahari, andreas.kahari@ebi.ac.uk

package Bio::Das::ProServer::SourceAdaptor::cache;

use strict;
use warnings;

use Cache::FileCache;
use Storable qw(freeze thaw);

sub new
{
    my $proto = shift;
    my $name = shift;

    my $class = ref $proto || $proto;

    my $self = {
	'cache'  => Cache::FileCache->new({
	    'namespace'		    => sprintf("%s_cache", $name),
	    'default_expires_in'    => 12*3600,	    # 12 hour
	    'auto_purge_interval'   => 600,	    # 10 minutes
	    'auto_purge_on_set'	    => 1,
	})
    };

    bless $self, $class;

    return $self;
}

sub get
{
    my $self = shift;
    my $key = shift;

    my $data = $self->{'cache'}->get($key);
    if (defined $data) {
	printf "cache: found '%s' in cache '%s'\n",
	    $key, $self->{'cache'}->get_namespace();
	return thaw($data);
    }

    return undef;
}

sub set
{
    my $self = shift;
    my $key = shift;
    my $data = shift;

    printf "cache: storing '%s' in cache '%s'\n",
	$key, $self->{'cache'}->get_namespace();
    $self->{'cache'}->set($key, freeze($data));
}

1;
__END__

=head1 NAME

Bio::Das::ProServer::SourceAdaptor::cache

=head1 VERSION

$Revision: 2.70 $

=head1 AUTHOR

Andreas Kahari <andreas.kahari@ebi.ac.uk>
Andy Jenkinson <andy.jenkinson@ebi.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 EMBL-EBI

=head1 DESCRIPTION

A convenient interface to a file cache for Perl objects. Objects in the cache
expire after 12 hours, and the cache is automatically purged every 10 minutes
or every 'set' event.

=head1 SYNOPSIS

  my $oCache = Bio::Das::ProServer::SourceAdaptor::cache->new('mycache');

=head1 SUBROUTINES/METHODS

=head2 new

  Initialises the cache.

=head2 get

  Gets an object from the cache, if present.
  
  my $oObject = $oCache->get($sKey);

=head2 set

  Stores an object in the cache and purges any expired objects.
  
  $oCache->set($sKey, $oObject);

=head1 DEPENDENCIES

=over

=item L<Cache::FileCache>

=item L<Storable>

=item L<Bio::Das::ProServer::SourceAdaptor>

=back

=head1 BUGS AND LIMITATIONS

  See the L<http://perldoc.perl.org/Storable.html> Storable manpage for details
  of problems with 64-bit data for certain Perl versions.

=cut
