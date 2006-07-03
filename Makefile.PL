use 5.005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Bio::Das::ProServer',
    VERSION_FROM      => 'eg/proserver', # finds $VERSION
    PREREQ_PM         => {
			  Getopt::Long              => undef,
			  POSIX                     => undef,
			  Sys::Hostname             => undef,
			  CGI                       => undef,
			  POE                       => undef,
			  POE::Filter::HTTPD        => undef,
			  POE::Wheel::ReadWrite     => undef,
			  POE::Wheel::SocketFactory => undef,
			  HTTP::Request             => undef,
			  HTTP::Response            => undef,
			  Config::IniFiles          => undef,
			  Compress::Zlib            => undef,
			  HTML::Entities            => undef,
			 },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
     (AUTHOR         => 'Roger M Pettett <rmp@sanger.ac.uk>') : ()),
);
