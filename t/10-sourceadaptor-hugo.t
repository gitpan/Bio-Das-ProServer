use strict;
use warnings;
use Test::More tests => 5;
my $foo = Bio::Das::ProServer::SourceAdaptor::Transport::dummy->new();

use_ok("Bio::Das::ProServer::SourceAdaptor::hugo");

my $cfg = {
	   'transport' => 'dummy',
	  };
my $sa  = Bio::Das::ProServer::SourceAdaptor::hugo->new({'config'=>$cfg});
isa_ok($sa, 'Bio::Das::ProServer::SourceAdaptor::hugo');
can_ok($sa, qw(init build_features));
isa_ok($sa->transport, 'Bio::Das::ProServer::SourceAdaptor::Transport::dummy');
is($sa->das_features({'segments'=>[qw(45)]}), qq(    <SEGMENT id="45" version="1.0" start="1" stop="">
    <FEATURE id="test407" label="test407">
      <TYPE id="hugo:4" category="hugo" reference="no" subparts="no" superparts="no">hugo:4</TYPE>
      <START>10004346</START>
      <END>23025902</END>
      <METHOD id="hugo">hugo</METHOD>
      <ORIENTATION>0</ORIENTATION>
      <NOTE>XyZ</NOTE>
      <LINK href="http://test.com/search?XyZ1">Testsource1:XyZ1</LINK>
      <LINK href="http://example.com/path/to/entry/ABC1">Testsource2:ABC1</LINK>
    </FEATURE>
    <FEATURE id="test408" label="test408">
      <TYPE id="hugo:4" category="hugo" reference="no" subparts="no" superparts="no">hugo:4</TYPE>
      <START>30349575</START>
      <END>40987093</END>
      <METHOD id="hugo">hugo</METHOD>
      <ORIENTATION>0</ORIENTATION>
      <NOTE>XyZ</NOTE>
      <LINK href="http://test.com/search?XyZ1">Testsource1:XyZ1</LINK>
      <LINK href="http://example.com/path/to/entry/ABC1">Testsource2:ABC1</LINK>
    </FEATURE>
    </SEGMENT>
));

package Bio::Das::ProServer::SourceAdaptor::Transport::dummy;
use strict;
use warnings;
use base qw(Bio::Das::ProServer::SourceAdaptor::Transport::generic);

sub query {
  my ($self, $query, @args) = @_;
  if($query =~ /name.*description/) {
    return [
	    {
	     'name'        => 'test407',
	     'type'        => 'testtype',
	     'chr_start'   => 10004346,
	     'chr_end'     => 23025902,
	     'description' => 'XyZ',
	    },
	    {
	     'name'        => 'test408',
	     'type'        => 'testtype',
	     'chr_start'   => 30349575,
	     'chr_end'     => 40987093,
	     'description' => 'XyZ',
	    },
	   ];
  } else {
    return [
	    {
	     'external_id' => 'XyZ1',
	     'name'        => 'Testsource1',
	     'url'         => 'http://test.com/search?%s',
	    },
	    {
	     'external_id' => 'ABC1',
	     'name'        => 'Testsource2',
	     'url'         => 'http://example.com/path/to/entry/%s',
	    },
	   ];
  }
}

1;
