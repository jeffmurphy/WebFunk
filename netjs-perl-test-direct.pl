#!/usr/bin/perl

use lib ".";
use Net::WebFunk::API;
use Data::Dumper;

my $exppath = "Net::WebFunk::API::Exposed";
my $baseurl = "http://localhost/api/";

print "Direct test of the Net::WebFunk::API functions\n";

my $api = new Net::WebFunk::API();
$api->setExposedNamespace($exppath);

print "Exposed Objects and Methods\n";
foreach my $exposedModule ($api->exposed()) {
	my $module = new $exposedModule;
	my $exmod = ref($module);
	print "\t$exmod\n";
	
	my $module = new $exmod;
	my $exposedMethods = $module->exposedMethodList();
    foreach my $methodName (@$exposedMethods) {
		print "\t\t$methodName\n";
	}
}

print "\n========= JS Header =========\n\n" . $api->JSHeader() . "\n\n" ;

foreach my $exposedModule ($api->exposed()) {
	my $module = new $exposedModule;
	print $module->JSStub($baseurl);
}

print "\n========= Perl Header =========\n\n". $api->PerlHeader() . "\n\n";

my $stubs = '';
foreach my $exposedModule ($api->exposed()) {
	my $module = new $exposedModule;
	print $module->PerlStub($baseurl);
	$stubs .= $module->PerlStub($baseurl);
}

my $pcode = $api->PerlHeader() . $stubs;

eval($pcode);
if ($@) {
	warn "Failed to eval perl code: $@";
} else {
	my $arguments = { 'param1' => 123, 'param2' => "chocolate" };
	print "Calling methodPublic synchronously..\n";
	my ($rv, $content) = Template::methodPublic($arguments, undef); # synchronous
	print "Returned with status: " . $rv . "\n";
	print "Content from server: " . Dumper($content) . "\n" if ($rv eq "OK");
	print "Error code from server: $content\n" if ($rv eq "NOK");

	print "\nCalling methodPublic asynchronously..\n";
	Template::methodPublic($arguments, \&mycallback);
}

exit 0;

sub mycallback {
	my $status = shift;
	my $content = shift;
	
	print "Inside callback, status is $status\n";
	print "Content from server: " . Dumper($content) . "\n" if ($status eq "OK");
	print "Error code from server: $content\n" if ($status eq "NOK");
}