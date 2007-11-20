#########
# Author:        avc
# Maintainer:    $Author: rmp $
# Created:       2004-02-05
# Last Modified: $Date: 2007/11/20 20:12:21 $
# Id:            $Id: gtfdb.pm,v 2.70 2007/11/20 20:12:21 rmp Exp $
# Source:        $Source: /cvsroot/Bio-Das-ProServer/Bio-Das-ProServer/lib/Bio/Das/ProServer/SourceAdaptor/gtfdb.pm,v $
# $HeadURL$
#
package Bio::Das::ProServer::SourceAdaptor::gtfdb;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor);
use Carp;

our $VERSION = do { my @r = (q$Revision: 2.70 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

sub init {
  my $self                = shift;
  $self->{'capabilities'} = {
			     'features'      => '1.0',
			     'feature-by-id' => '1.0',
			     'types'         => '1.0',
			    };
  return;
}


sub build_features {
  my ($self, $opts) = @_;
  
  if ($opts->{'feature_id'}) {
    return $self->build_features_by_id($opts);

  } elsif ($opts->{'segment'}) {
    return $self->build_features_by_segment($opts);

  } elsif ($opts->{'note'}) {#sr5 ...needs changing
    return $self->build_diff_features($opts);

  }

  carp q(unsupported feature fetch request!);
  return;
}

sub build_features_by_segment  {
  my ($self, $opts) = @_;
  my $seg = $opts->{'segment'};
  my ($end, $start);
  
  if ( $opts->{'end'} && ! $opts->{'start'}) {
    carp "no segment start in segment request!\n";
    return;

  } elsif ( $opts->{'start'} && ! $opts->{'end'})  {
    carp "no segment end in segment request!\n";
    return;
  }
  
  my $table_name = $self->config->{'tablename'};
  my ($query, @params);
  if ($opts->{'start'} && $opts->{'end'}) {
    $start = $opts->{'start'};
    $end   = $opts->{'end'};
    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    $query = qq(SELECT DISTINCT id,
                       chr,
                       start,
                       end,
                       orientation AS ori,
                       type
                FROM  $table_name
                WHERE chr    = ? 
                AND   start <= ? 
                AND   end   >= ?);
    @params = ($seg, $end, $start);

  } else {
    $query = qq(SELECT DISTINCT id,
                       chr,
                       start,
                       end,
                       orientation,
                       type
                FROM   $table_name
                WHERE  chr = ?);
    @params = ($seg);
  }
  
  my $ref = $self->transport->query($query, @params);
  
  return map {
    {
      'segment'         => $_->{'chr'},
      'id'              => $_->{'id'},
      'type'            => $_->{'type'} . q(:ssaha2),
      'method'          => $_->{'type'} . q(:ssaha2),
      'segment_start'   => $opts->{'start'},
      'segment_end'     => $opts->{'end'},
      'start'           => $_->{'start'},
      'end'             => $_->{'end'},
      'ori'             => $_->{'orientation'},
      'segment_version' => 1,
    };
  } @{$ref};
}

sub build_features_by_id  {
  my ($self, $opts) = @_;
  my $cloneid = $opts->{'feature_id'};
  #$cloneid    =~ s/(\w+)\.\d+/$1/; # remove any version number

  my $table_name = $self->config->{'tablename'};
  my $query = qq(SELECT DISTINCT id,
                        chr,
                        start,
                        end,
                        orientation,
                        type
                 FROM   $table_name
                 WHERE  id LIKE ?
                 GROUP BY start);

  my $ref = $self->transport->query($query, "$cloneid%");

  return map {
    {
      'segment'         => $_->{'chr'},
      'id'              => $_->{'id'},
      'type'            => $_->{'type'} . q(:ssaha2),
      'method'          => $_->{'type'} . q(:ssaha2),
      'segment_start'   => 1,
      'segment_end'     => 1,
      'start'           => $_->{'start'},
      'end'             => $_->{'end'},
      'ori'             => $_->{'orientation'},
      'segment_version' => 1,
    };
  } @{$ref};
}

sub length { ## no critic
  my ($self, $var) = @_;
  $self->{'_length'} ||= $var;
  return $self->{'_length'};
}

sub build_types {
  return (
	  {
	   'method'   => 'ssaha2',
	   'category' => 'default',
	   'type'     => 'spectral_genomics_clone',
	  },
	  {
	   'method'   => 'ssaha2',
	   'category' => 'default',
	   'type'     => 'spectral_genomics_clone',
	  },
	 );
}

sub build_nongrpd_features { #sr5...
  my ($self, $opts) = @_;
  my $table_name    = $self->config->{'tablename'};
  my $seg           = $opts->{'segment'};
  my ($end, $start, $query);

  if ($opts->{'start'} && $opts->{'end'}) {
    $start         = $opts->{'start'};
    $end           = $opts->{'end'};
    if($start > $end) {
      ($start, $end) = ($end, $start);
    }
    $query         = qq(SELECT id,
                               label,
                               start,
                               end,
                               score,
                               orient        AS ori,
                               phase,
                               type_id       AS type,
                               type_category AS typecategory,
                               method,
                               group_id      AS group,
                               target_start,
                               target_end,
                               target_id,
                               link_uri      AS link,
                               link_text     AS linktxt,
                               note
                        FROM  $table_name
                        WHERE chr    = ?
                        AND   start <= ?
                        AND   end   >= ?
                        ORDER BY start);
  }

  return @{$self->transport->query($query, $seg, $end, $start)};
}



1;
__END__

=head1 NAME

Bio::Das:ProServer::SourceAdaptor::gtfdb - Builds DAS features for Human Spectral Genomics cloneset from mapping database

=head1 VERSION

$Revision: 2.70 $

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SUBROUTINES/METHODS

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Tony Cox <avc@sanger.ac.uk>.

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2007 The Sanger Institute

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.  See DISCLAIMER.txt for
disclaimers of warranty.

=cut

