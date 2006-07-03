#!/usr/local/bin/perl
use lib "/nfs/team71/web/rmp/incoming/work/perl/";
use Bio::Das::ProServer::SourceAdaptor::Transport::file;

my $tp = Bio::Das::ProServer::SourceAdaptor::Transport::file->new();
$tp->{'filename'} = "/nfs/team71/web/rmp/incoming/work/perl/genesat/genelist.txt";

my $ref = $tp->query(qq(field0 like 'at%'));
for my $result (@{$ref}) {
  print @{$result}[2], "\n";
}

