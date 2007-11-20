use Test::More tests => 1;

my $sa = SA::Stub->new();
my $expected_response = q(<SEGMENT id="test" version="1.0" start="1" stop=""><FEATURE id="1" label="1"><TYPE id=""></TYPE><START>0</START><END>0</END><TARGET id="t1" start="123" stop="234">target t1</TARGET></FEATURE><FEATURE id="2" label="2"><TYPE id=""></TYPE><START>0</START><END>0</END><TARGET id="t2" start="345" stop="456">target t2</TARGET><TARGET id="t3" start="567" stop="678">target t3</TARGET></FEATURE></SEGMENT>);

is_deeply($sa->das_features({
		      'segments' => ['test'],
		     }), $expected_response, "target response");


package SA::Stub;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub build_features {
  return (
	  {
	   'feature_id'   => 1,
	   'target_id'    => 't1',
	   'target_start' => '123',
	   'target_stop'  => '234',
	   'targettxt'    => 'target t1',
	  },
	  {
	   'feature_id'   => 2,
	   'target'       => [
			      {
			       'id'        => 't2',
			       'start'     => '345',
			       'stop'      => '456',
			       'targettxt' => 'target t2',
			      },
			      {
			       'id'        => 't3',
			       'start'     => '567',
			       'stop'      => '678',
			       'targettxt' => 'target t3',
			      },
			     ],
	  },
	 );
}

1;

