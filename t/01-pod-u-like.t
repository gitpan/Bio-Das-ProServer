use Test::More;
use Test::Pod::Coverage 1.00;

plan tests => 10;
#pod_coverage_ok("eg/proserver");
pod_coverage_ok("Bio::Das::ProServer::Config");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor");
pod_coverage_ok("Bio::Das::ProServer::SourceHydra");
pod_coverage_ok("Bio::Das::ProServer::SourceHydra::dbi");
pod_coverage_ok("Bio::Das::ProServer::SourceHydra::ppid");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor::Transport::generic");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor::Transport::file");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor::Transport::csv");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor::Transport::dbi");
pod_coverage_ok("Bio::Das::ProServer::SourceAdaptor::Transport::oracle");
