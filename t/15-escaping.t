use Test::More tests => 2;
my $sa = SA::Stub->new();
my $expected_feat_response = q(<SEGMENT id="&#x3C;test&#x3E;" version="1.0" start="1" stop=""><FEATURE id="1" label="1"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=one&#x26;test=1" /></FEATURE><FEATURE id="2" label="2"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=two&#x26;test=2">test two</LINK></FEATURE><FEATURE id="3" label="3"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=three&#x26;test=3" /><LINK href="http://mysite.com/link?test=threeb&#x26;test=3b" /></FEATURE><FEATURE id="4" label="4"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=four&#x26;test=4">test&#x26;nbsp;4a</LINK><LINK href="http://mysite.com/link?test=fourb&#x26;test=4b">test 4b</LINK></FEATURE><FEATURE id="5" label="5"><TYPE id="test">test</TYPE><START>0</START><END>0</END><LINK href="http://mysite.com/link?test=five&#x26;test=5">test&#x26;nbsp;5</LINK><LINK href="http://mysite.com/link?test=five&#x26;nbsp;b&#x26;test=5b">test&#x26;nbsp;5b</LINK></FEATURE></SEGMENT>);
my $expected_type_response = q(<SEGMENT id="&#x3C;test&#x3E;" start="1" stop="" version="1.0"><TYPE id="interesting&#x26;nbsp;feature" description="See &#x3C;a href=&#x22;http://www.mysite.com/mydastypes&#x22;&#x3E;here&#x3C;/a&#x3E; for more info.">1</TYPE></SEGMENT>);

is_deeply($sa->das_features({
		      'segments' => ['<test>'],
		     }), $expected_feat_response, "escaped features response");
is_deeply($sa->das_types({
		      'segments' => ['<test>'],
		     }), $expected_type_response, "escaped types response");


package SA::Stub;
use base qw(Bio::Das::ProServer::SourceAdaptor);

sub build_types {
  return (
          {
           'type'        => 'interesting&nbsp;feature',
           'description' => 'See <a href="http://www.mysite.com/mydastypes">here</a> for more info.',
           'count'       => '1',
          }
         );
}

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
	   'linktxt'    => [ 'test&nbsp;4a', 'test 4b'],
	  },
	  {
	   'feature_id' => 5,
	   'type'       => 'test',
	   'link'       => {
			    'http://mysite.com/link?test=five&test=5' => 'test&nbsp;5',
			    'http://mysite.com/link?test=five&nbsp;b&test=5b' => 'test&nbsp;5b',
			   },
	  },
	 );
}

1;

