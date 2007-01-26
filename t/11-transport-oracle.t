use strict;
use warnings;
use Test::More tests => 3;
use_ok("Bio::Das::ProServer::SourceAdaptor::Transport::oracle");
my $t = Bio::Das::ProServer::SourceAdaptor::Transport::oracle->new();
isa_ok($t, 'Bio::Das::ProServer::SourceAdaptor::Transport::oracle');
can_ok($t, qw(dbh query prepare disconnect DESTROY));
