#########
# Author:        rmp
# Last Modified: $Date: 2008-03-12 14:50:11 +0000 (Wed, 12 Mar 2008) $ $Author: andyjenkinson $
# Id:            $Id: critic.t 453 2008-03-12 14:50:11Z andyjenkinson $
# Source:        $Source: /cvsroot/Bio-DasLite/Bio-DasLite/t/00-critic.t,v $
# $HeadURL: https://zerojinx@proserver.svn.sf.net/svnroot/proserver/trunk/t/critic.t $
#
package critic;
use strict;
use warnings;
use Test::More;
use English qw(-no_match_vars);

our $VERSION = do { my @r = (q$LastChangedRevision: 453 $ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

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
