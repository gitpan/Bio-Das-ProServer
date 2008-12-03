#########
# Author:        rmp
# Last Modified: $Date: 2008-09-21 19:34:09 +0100 (Sun, 21 Sep 2008) $ $Author: andyjenkinson $
# Id:            $Id: distribution.t 526 2008-09-21 18:34:09Z andyjenkinson $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-distribution.t,v $
# $HeadURL: https://proserver.svn.sf.net/svnroot/proserver/trunk/t/distribution.t $
#
package distribution;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use lib qw(t/dummy);

our $VERSION = do { my ($v) = (q$LastChangedRevision: 526 $ =~ /\d+/mxg); $v; };

eval {
  require Test::Distribution;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Distribution not installed';

} else {
  Test::Distribution->import();
}

1;
