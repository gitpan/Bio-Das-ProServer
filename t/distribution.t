#########
# Author:        rmp
# Last Modified: $Date: 2008-12-10 12:47:05 +0000 (Wed, 10 Dec 2008) $ $Author: andyjenkinson $
# Id:            $Id: distribution.t 560 2008-12-10 12:47:05Z andyjenkinson $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-distribution.t,v $
# $HeadURL: https://proserver.svn.sourceforge.net/svnroot/proserver/tags/spec-1.53/t/distribution.t $
#
package distribution;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use lib qw(t/dummy);

our $VERSION = do { my ($v) = (q$LastChangedRevision: 560 $ =~ /\d+/mxg); $v; };

if (!$ENV{TEST_AUTHOR}) {
  my $msg = 'Author test.  Set the TEST_AUTHOR environment variable to a true value to run.';
  plan( skip_all => $msg );
}

eval {
  require Test::Distribution;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Distribution not installed';

} else {
  Test::Distribution->import();
}

1;
