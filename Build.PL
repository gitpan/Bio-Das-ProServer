use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new (
    module_name         => 'Bio::Das::ProServer',
    dist_author         => 'Roger M Pettett <rmp@sanger.ac.uk>',
    dist_version_from   => 'eg/proserver',
    dist_abstract       => 'Bio::Das::ProServer is an implementation of the BioDAS protocol,
http://biodas.org/ for the serving of biological data using XML over
HTTP.

Bio::Das::ProServer is designed as a lightweight alternative to some
other DAS servers. Version 2.0 is a drop-in replacement for previous
versions but has a core based on the POE system which is much better
tested and debugged than the ProServer v1 core. ProServer can be seen
as the server-side complement to the Bio-DasLite client.

More information can be found at the ProServer homepage:

    http://www.sanger.ac.uk/proserver/',
    license             => 'perl',
    requires => {
	'File::Spec'                   => 3.25,
	'POSIX'                        => 1.08,
	'CGI'                          => 3.29,
	'Socket'                       => 1.77,
	'POE'                          => 0.9999,
	'Getopt::Long'                 => 2.34,
	'Sys::Hostname'                => 1.11,
	'POE::Filter::HTTPD'           => 1.2188,
	'POE::Wheel::ReadWrite'        => 1.2199,
	'POE::Wheel::SocketFactory'    => 1.2194,
	'HTTP::Request'                => 1.40,
	'HTTP::Response'               => 1.53,
	'HTTP::Date'                   => 1.47,
	'Compress::Zlib'               => 2.005,
	'HTML::Entities'               => 1.27,
	'Readonly'                     => '1.03',
    },
    recommends => {
      'DBI'                            => 1.52,      # for database-backed SourceAdaptors
      'LWP::UserAgent'                 => 2.033,     # Optional, for Transport::wgetz,
                                                     #   SourceAdaptor::proxy and Authenticator::http
      'Cache::Cache'                   => 1.05,      # Optional, for Authenticator::http
      'Net::IP'                        => 1.25,      # Optional, for Authenticator::ip
      'Bio::Das::Lite'                 => 1.051,     # Optional, for SourceAdaptor::proxy
      'Bio::DB::Flat'                  => 0,         # Optional, for Transport::bioseqio (BioPerl)
      'Bio::SeqIO'                     => 0,         # Optional, for Transport::bioseqio (BioPerl)
      'Bio::EnsEMBL::DBSQL::DBAdaptor' => 0,         # Optional, for SourceAdaptor::ensembl (Ensembl core)
      'Bio::EnsEMBL::Registry'         => 0,         # Optional, for SourceAdaptor::ensembl (Ensembl core)
    },
    build_requires => {
	'Test::More'                     => 0,
    },
    build_recommends => {
	'Test::Distribution'             => 0,
	'Test::Perl::Critic'             => 0,
    },
    create_makefile_pl  => 'passthrough',
);

$builder->create_build_script();
