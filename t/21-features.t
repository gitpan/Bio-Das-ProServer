use strict;
use warnings;
use Test::More tests => 3;
my $sa = SA::FeaturesStub->new();

my $expected_response = q(<SEGMENT id="seg-1" version="1.0" start="100" stop="200"><FEATURE id="feat-1" label="feat-1"><TYPE id="t">t</TYPE><START>100</START><END>200</END><GROUP id="grp-1"/></FEATURE></SEGMENT>);
my $response = $sa->das_features({'segments' => ['seg-1:100,200']});
is_deeply($response, $expected_response, "segment version in separate method");

$expected_response = q(<SEGMENT id="seg-2" version="1.0" start="200" stop="300"><FEATURE id="feat-2" label="feat-2"><TYPE id="t">t</TYPE><START>200</START><END>300</END><GROUP id="grp-2"/></FEATURE></SEGMENT>);
$response = $sa->das_features({'features' => ['feat-2']});
is_deeply($response, $expected_response, "segment version in feature hash");

$expected_response = q(<SEGMENT id="seg-3" version="1.0" start="300" stop="400"><FEATURE id="feat-3" label="feat-3"><TYPE id="t">t</TYPE><START>300</START><END>400</END><GROUP id="grp-3"/></FEATURE></SEGMENT>);
$response = $sa->das_features({'groups' => ['grp-3']});
is_deeply($response, $expected_response, "segment version not providedd");

package SA::FeaturesStub;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub init {
  my $self = shift;
  $self->{'features'} = [
    {
     'segment'         => 'seg-1',
     'start'           => '100',
     'end'             => '200',
     'id'              => 'feat-1',
     'group'           => 'grp-1',
     'type'            => 't',
    },
    {
     'segment'         => 'seg-2',
     'start'           => '200',
     'end'             => '300',
     'id'              => 'feat-2',
     'group'           => 'grp-2',
     'type'            => 't',
    },
    {
     'segment'         => 'seg-3',
     'start'           => '300',
     'end'             => '400',
     'id'              => 'feat-3',
     'group'           => 'grp-3',
     'type'            => 't',
    },
   ];
}

sub build_features {
  my ($self, $params) = @_;
  if ($params->{'feature_id'}) {
    my %all = map { $_->{'id'} => $_ } @{ $self->{'features'} };
    return ($all{$params->{'feature_id'}});
  } elsif ($params->{'group_id'}) {
    my %all = map { $_->{'group'} => $_ } @{ $self->{'features'} };
    return ($all{$params->{'group_id'}});
  } else {
    my %all = map { $_->{'segment'} => $_ } @{ $self->{'features'} };
    return ($all{$params->{'segment'}});
  }
}

1;
__DATA__
seg-1  feat-1  grp-1  