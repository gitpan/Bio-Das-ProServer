use strict;
use Test::More tests => 20;
use Bio::Das::ProServer::Config;
use_ok('Bio::Das::ProServer::SourceAdaptor');

my $sa = Bio::Das::ProServer::SourceAdaptor->new();
isa_ok($sa, 'Bio::Das::ProServer::SourceAdaptor');
can_ok($sa, qw(new init length mapmaster description init_segments known_segments segment_version dsn dsnversion start end transport config implements das_capabilities das_dsn open_dasdsn close_dasdsn open_dasgff close_dasgff unknown_segment _gen_link_das_response _encode _gen_feature_das_response das_features error_feature open_dasdna open_dassequence das_dna das_sequence close_dasdna close_dassequence open_dastypes close_dastypes das_types open_dasep close_dasep das_entry_points das_stylesheet das_homepage das_alignment genAlignObjectDasResponse genAlignScoreDasResponse genAlignBlockDasResponse genAlignGeo3dDasResponse das_structure genObjectDasResponse genChainDasResponse genConnectDasResponse cleanup));
is($sa->init(),             undef,         'init is undef');
is($sa->length(),           0,             'length is 0 by default');
is($sa->mapmaster(),        undef,         'mapmaster is undef');
is($sa->description(),      undef,         'description is undef');
is($sa->init_segments(),    undef,         'init_segments is undef');
is($sa->known_segments(),   undef,         'known_segments is undef');
is($sa->segment_version(),  undef,         'segment_version is undef');
is($sa->dsn(),              'unknown',     'dsn is unknown');
is($sa->dsnversion(),       '1.0',         'dsn version is 1.0');
is($sa->start(),            1,             'start is 1');
is($sa->end(),              $sa->length(), 'end == length');
isa_ok($sa->config(),       'HASH',        'config is a hash');
my $cfg = {
	   'transport' => 'file',
	  };
$sa->config($cfg);
is($sa->config(),           $cfg,          'config get/set ok');
isa_ok($sa->transport(),    'Bio::Das::ProServer::SourceAdaptor::Transport::file', 'file transport created ok');   
is($sa->implements('dsn'),  1,             'implements dsn ok');
is($sa->implements(),       undef,         'implements without arg gives undef');
is($sa->das_capabilities(), 'dsn/1.0',     'das_capabilities gives a basic dsn/1.0');
