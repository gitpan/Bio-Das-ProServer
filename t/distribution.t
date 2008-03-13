#########
# Author:        rmp
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $ $Author: andyjenkinson $
# Id:            $Id: distribution.t 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-distribution.t,v $
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/t/distribution.t $
#
package distribution;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);
use lib qw(t/dummy);

our $VERSION = do { my @r = (q$LastChangedRevision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

eval {
  require Test::Distribution;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Distribution not installed';

} else {
  Test::Distribution->import();
}

1;
