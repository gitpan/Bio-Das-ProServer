use 5.005;
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    AUTHOR       => 'Roger M Pettett <rmp@sanger.ac.uk>',
    NAME         => 'Bio::Das::ProServer',
    VERSION_FROM => 'eg/proserver', # finds $VERSION
    PREREQ_PM    => {
                     'File::Spec'                     => 3.2501,
                     'POSIX'                          => 1.09,
                     'CGI'                            => 3.33,
                     'Socket'                         => 1.78,
                     'POE'                            => 0.9999,
                     'Getopt::Long'                   => 2.37,
                     'Sys::Hostname'                  => 1.11,
                     'POE::Filter::HTTPD'             => 1.2188,
                     'POE::Wheel::ReadWrite'          => 1.2199,
                     'POE::Wheel::SocketFactory'      => 1.2194,
                     'HTTP::Request'                  => 1.40,
                     'HTTP::Response'                 => 1.53,
                     'HTTP::Date'                     => 1.47,
                     'Config::IniFiles'               => 2.38,
                     'Compress::Zlib'                 => 2.008,
                     'HTML::Entities'                 => 1.35,
                     'DBI'                            => 1.601,     # Optional, for database-backed SourceAdaptors
                     'LWP::UserAgent'                 => 2.033,     # Optional, for Transport::wgetz, SourceAdaptor::proxy and Authenticator::http
                     'Cache::FileCache'               => 1.05,      # Optional, for Authenticator::http
                     'Net::IP'                        => 1.25,      # Optional, for Authenticator::ip
                     'Bio::Das::Lite'                 => 1.051,     # Optional, for DAS-client processing
                     'Bio::DB::Flat'                  => 1.0050021, # Optional, for Transport::bioseqio
                     'Bio::SeqIO'                     => 1.0050021, # Optional, for Transpotr::bioseqio
                     'Bio::EnsEMBL::DBSQL::DBAdaptor' => 0,         # Optional, for SourceAdaptor::ensembl
                     'Bio::EnsEMBL::Registry'         => 0,         # Optional, for SourceAdaptor::ensembl
                     'Bio::Pfam::Structure::Chainset' => 0,         # Optional, for Transport::pdbStructure
                    },
);
