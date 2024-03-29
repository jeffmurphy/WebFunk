use 5.008008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Net::WebFunk::API',
    VERSION_FROM      => 'lib/Net/WebFunk/API.pm', # finds $VERSION
    PREREQ_PM         => {
				'JSON'  => 0,
				'Moose' => 1.08,
				'Class::MOP' => 1.04,
				'Module::Pluggable' => 0,
				'Pod::POM' => 0,
				'Pod::POM::View::HTML' => 0,
				'LWP' => 0,
				'LWP::UserAgent' => 0,
				'Apache2::Request' => 0,
				'Apache2::RequestRec' => 0,
				'Apache2::RequestIO' => 0,
				'Apache2::Const' => 0,
				'Apache2::URI' => 0
			}, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT       => 'Lightweight Multi-language HTTP RPC', # retrieve abstract from module
       AUTHOR         => 'Robert Colantuoni <rgc@colantuoni.com>, Jeff Murphy <jcmurphy@jeffmurphy.com>') : ()),
);
