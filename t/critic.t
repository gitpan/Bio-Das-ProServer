#########
# Author:        rmp
# Last Modified: $Date: 2008-09-21 19:34:09 +0100 (Sun, 21 Sep 2008) $ $Author: andyjenkinson $
# Id:            $Id: critic.t 526 2008-09-21 18:34:09Z andyjenkinson $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-critic.t,v $
# $HeadURL: https://proserver.svn.sf.net/svnroot/proserver/trunk/t/critic.t $
#
package critic;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

our $VERSION = do { my ($v) = (q$LastChangedRevision: 526 $ =~ /\d+/mxg); $v; };

if (!$ENV{TEST_AUTHOR}) {
  my $msg = 'Author test.  Set the TEST_AUTHOR environment variable to a true value to run.';
  plan( skip_all => $msg );
}

eval {
  require Test::Perl::Critic;
};

if($EVAL_ERROR) {
  plan skip_all => 'Test::Perl::Critic not installed';

} else {
  Test::Perl::Critic->import(
			     -severity => 1,
			     -exclude => [qw(tidy
					     Subroutines::ProhibitExcessComplexity
					     ValuesAndExpressions::ProhibitImplicitNewlines)],
			    );
  all_critic_ok();
}

1;
