#!/usr/bin/perl

use lib ".";
use Net::WebFunk::API;
use Data::Dumper;

my $baseurl = "http://localhost/api/";

print "HTTP test of the Net::WebFunk::API functions\n";

print "\nFetching Perl header...\n\n";
my $pcode = fetchPerlHeader($baseurl);

eval($pcode);
if ($@) {
	warn "Failed to eval perl code: $@";
} else {
	my $arguments = { 'param1' => 123, 'param2' => "chocolate" };
	
	print "Calling methodPublic with direct return values..\n";

	my ($rv, $content) = Template::methodPublic($arguments, undef); # synchronous

	print "Returned with status: " . $rv . "\n";
	print "Content from server: " . Dumper($content) . "\n" if ($rv eq "OK");
	print "Error code from server: $content\n" if ($rv eq "NOK");

	# while JS XHR has a simple asynch/sync functionality, LWP doesnt really so the
	# call back is sort of moot. its included to keep the API consistent between
	# the two languages. You could use LWP::Parallel perhaps, ... 
		
	print "\nCalling methodPublic via callback..\n";

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


sub fetchPerlHeader {
    my $baseurl = shift;
	
    use LWP::UserAgent;
    my $ua = LWP::UserAgent->new;
    $ua->agent("MyApp/0.1");

    # Create a request
    my $req = HTTP::Request->new(GET => $baseurl);
	$req->header(Accept => "application/perl");

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ($res->is_success) {
		return $res->content;
    }
    else {
        die "failed to fetch perlheader: ". $res->status_line;
    }
}
