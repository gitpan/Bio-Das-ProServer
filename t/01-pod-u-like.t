use strict;
use warnings;
use Test::More;
use Test::Pod::Coverage 1.00;

my @pkgs = qw(Config
	      SourceAdaptor::Transport::generic
	      SourceAdaptor::Transport::file
	      SourceAdaptor::Transport::csv
	      SourceAdaptor::Transport::dbi
	      SourceAdaptor::Transport::oracle
	      SourceAdaptor
	      SourceAdaptor::simple
	      SourceAdaptor::simpledb
	      SourceHydra
	      SourceHydra::dbi
	      SourceHydra::ppid);

plan tests => scalar @pkgs;
for my $pkg (@pkgs) {
  pod_coverage_ok("Bio::Das::ProServer::$pkg");
}
