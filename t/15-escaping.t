use Test::More tests => 1;
my $sa = SA::Stub->new();
my $expected_response = q(<SEGMENT id="test" version="1.0" start="1" stop=""><FEATURE id="1" label="1"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=one&amp;test=1">http://mysite.com/link?test=one&amp;test=1</LINK></FEATURE><FEATURE id="2" label="2"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=two&amp;test=2">test two</LINK></FEATURE><FEATURE id="3" label="3"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=three&amp;test=3">http://mysite.com/link?test=threeb&amp;test=3b</LINK></FEATURE><FEATURE id="4" label="4"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=four&amp;test=4">test 4a</LINK><LINK href="http://mysite.com/link?test=fourb&amp;test=4b">test 4b</LINK></FEATURE></SEGMENT>);

is_deeply($sa->das_features({
		      'segments' => ['test'],
		     }), $expected_response, "escaped response");


package SA::Stub;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub build_features {
  return (
	  {
	   'feature_id' => 1,
	   'type'       => 'test',
	   'link'       => "http://mysite.com/link?test=one&test=1",
	  },
	  {
	   'feature_id' => 2,
	   'type'       => 'test',
	   'link'       => "http://mysite.com/link?test=two&test=2",
	   'linktxt'    => 'test two',
	  },
	  {
	   'feature_id' => 3,
	   'type'       => 'test',
	   'link'       => [
			    'http://mysite.com/link?test=three&test=3',
			    'http://mysite.com/link?test=threeb&test=3b',
			   ],
	  },
	  {
	   'feature_id' => 4,
	   'type'       => 'test',
	   'link'       => [
			    'http://mysite.com/link?test=four&test=4',
			    'http://mysite.com/link?test=fourb&test=4b',
			   ],
	   'linktxt'    => [ 'test 4a', 'test 4b'],
	  },
	 );
}

1;

