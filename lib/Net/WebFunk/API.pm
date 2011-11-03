package Net::WebFunk::API;


use Moose; # automatically turns on strict and warnings
use Module::Pluggable search_path => ['Net::Funk::API::Exposed'], sub_name => 'exposed', require => 1;
use JSON;
use Data::Dumper;

our $VERSION = '0.07';

has '_r' => (is => 'rw', isa => 'Apache2::RequestRec', required => 1);

=head1 NAME

Net::Funk::API - This module provides a simple way to provide a multilanguage RPC interface to a perl
backend. 

=head1 SYNOPSIS

  use Net::WebFunk::API;

=head1 DESCRIPTION

This module presents some boilerplate routines in a language of the caller's choice. 
The routines facilitate calling the remote procedure but can generally be ignored by 
the caller. Currently WebFunk offers Perl and Javascript client bindings.

=head1 ROUTINES

=cut

my $D = 0;

sub debug {
	my $n = shift;
	$D = defined($n) ? $n : !$D;
	return $D;
}

sub setExposedNamespace {
	my ($self, $ns) = (@_);
	$self->search_path(new => $ns) if(defined($ns));
}

sub exposedNamespace {
	my ($self) = (@_);
	return @{$self->search_path}[0];
}

sub exposedMethodList {
	my ($self) = (@_);

	my @funcs = ();

    my $methodMap = $self->meta->_full_method_map;

    foreach my $methodName (keys %$methodMap) {
    	next if($methodName eq 'meta');  # hide 'meta' function
		next if($methodName =~ /^_/);    # hide private functions, preceded by underscore
        push(@funcs, $methodMap->{$methodName}->{'name'});
	}

	return \@funcs;

}

=head2 mydoc

Extract our Pod documentation and present it as HTML

=cut

sub mydoc {
	use Pod::POM;
	use Pod::POM::View::HTML;
	
	my $self   = shift;
	my $donly  = shift || 0;
	my $path   = $self->mypath();
	return "Documentation unavailable." unless defined $path;
	
	my $parser = new Pod::POM();
	my $pom    = $parser->parse_file($path);
	
	if (!defined($pom)) {
		print STDERR "Pod::POM failure for path $path error ". $parser->error();
		return "Documentation unavailable.";
	}
	
	if ($donly) {
		# just return the description (the NAME head1 block if available)
		foreach my $head1 ($pom->head1()) {
			return $head1->content() if ($head1->title() eq "NAME");
		}
		return "No description available (NAME head1).";
	}

	return Pod::POM::View::HTML->print($pom);
}

=head2 mypath

Discover the path to our module given our package. Thought about looking for 

	/Net.WebFunk.API/

iteratively, but not thrilled about that overhead for each API call. Instead we
construct the exact package name

	Net/WebFunk/API.pm

and test directly. Currently we assume Unix path seps. Havent checked to seek 
if Perl on Windows puts Net\WebFunk\API.pm into the INC hash. 

=cut


sub mypath {
	my $self = shift;
	my $pkg = ref($self) . ".pm";
	$pkg =~ s/::/\//g; # FIX unix only
	return $INC{$pkg} if (exists $INC{$pkg});
	return undef;
}

=head2 JSHeader

If the client requested javascript, this routine produces the appropriate code. The client
doesn't call these routines directly and instead calls the methods generated by JSStub()

=cut


sub JSHeader {
	my ($self) = (@_);

	my $buffer = qq|

function getHTTPObject() {
	var xhr = false; //set to false, so if it fails, do nothing
	if(window.XMLHttpRequest) { //detect to see if browser allows this method
		var xhr = new XMLHttpRequest(); //set var the new request
	} else if(window.ActiveXObject) { //detect to see if browser allows this method
		try {
			var xhr = new ActiveXObject("Msxml2.XMLHTTP"); //try this method first
		} catch(e) { //if it fails move onto the next
			try {
				var xhr = new ActiveXObject("Microsoft.XMLHTTP"); //try this method next
			} catch(e) { //if that also fails return false.
				xhr = false;
			}
		}
	}
	return xhr;
}

function debugHandler(objjself, objjsel, s) {
	var obj = JSON.parse(s.toString());
	alert("raw reply: " + s + " decoded reply: status=" + obj.status + ", message=" + obj.message);
}

function getMethod(url, obj, callback, objjself, objjselector) {
		var http = getHTTPObject();
		if (JSON != undefined) {
				var async = (typeof(callback) == "function") ? true : false;
				http.open("POST", url, async);
				http.setRequestHeader("Accept", "application/javascript");
				http.setRequestHeader('User-Agent', "WebFunk/${VERSION};" + (callback ? "a" : "") + "synchronous");
				if (async) {
					http.onreadystatechange = function() {
						if (http.readyState == 4)
							if (http.status == 200)
								callback(objjself, objjselector, JSON.parse(http.responseText.toString()));
					}
				}
				http.send(JSON.stringify(obj));
				if (async == false) return JSON.parse(http.responseText.toString());
		} else 
			alert ("You must install and include JSON.js (Net::WebFunk::API)");
}

|;

	return $buffer;
}

=head2 PerlHeader

If the client requested Perl, this routine produces the appropriate code. The client
doesn't call these routines directly and instead calls the methods generated by PerlStub()

=cut


sub PerlHeader {
	my ($self) = (@_);

	my $buffer = qq|
package WebFunkAPI;
use LWP;
use LWP::UserAgent;
use JSON;

sub getMethod {
	my (\$url, \$obj, \$callback) = \@_;
	err \$callback, "url must be specified" unless (defined(\$url) && (ref(\$url) eq ""));
	err \$callback, "obj must be a hashref" unless (defined(\$obj) && (ref(\$obj) eq "HASH"));
	my \$ua = new LWP::UserAgent();
	err \$callback, "couldnt make new LWP::UserAgent" unless \$ua;
	\$ua->agent("WebFunk/${VERSION};" . (defined(\$callback) ? "a" : "") . "synchronous");
	my \$req = new HTTP::Request(POST => \$url);
	err \$callback, "couldnt make new HTTP::Request" unless \$req;
	\$req->content_type('application/x-www-form-urlencoded');
	\$req->content(encode_json(\$obj));
	\$req->header('Accept' => "application/perl");
	my \$res = \$ua->request(\$req);
	err \$callback, "undefined response from HTTP::Request" unless \$res;
	if (\$res->is_success) {
		if (defined(\$callback)) {
			\&\$callback("OK", decode_json(\$res->content));
			return;
		} else {
			return "OK", decode_json(\$res->content);
		}
	} else {
		if (defined(\$callback)) {
			\&\$callback("NOK", { 'code' => \$res->code, 'message' => \$res->status_line } );
			return;
		} else {
			return "NOK", { 'code' => \$res->code, 'message' => \$res->status_line } ;
		}
	}
	#NOTREACHED
}

sub err {
	my \$callback = shift; 
	my \$msg = shift;
	if (defined(\$callback)) {
	    \&\$callback("NOK", \$msg);
	    return;
	}
    return "NOK", \$msg;
}
|;

	return $buffer;
}

=head2 PerlStub

If the client request Perl, this routine produces the appropriate method code that the client
can directly use to call the remote methods.

=cut

sub PerlStub {
    my ($self, $url) = (@_);
	my $moduleName = $self->meta->{package};

	$url =~ s/\/$//g;

	my $exposedNamespace = $self->exposedNamespace();
	$moduleName =~ s/$exposedNamespace\:\://g;

    my @functionList = ();

	my $exposedMethods = $self->exposedMethodList();
    foreach my $methodName (@$exposedMethods) {
		my $funcCode = "sub ${moduleName}::${methodName} { return WebFunkAPI::getMethod('$url/$moduleName/$methodName/', shift, shift); }";
        push (@functionList, $funcCode);
    }

	my $buffer = join("\n", @functionList) . "\n"; 

    return $buffer;
}

=head2 JSStub

If the client requested javascript, this routine produces the appropriate method code that the client
can directly use to call the remote methods.

=cut

sub JSStub {
    my ($self, $url) = (@_);
	my $moduleName = $self->meta->{package};

	$url =~ s/\/$//g;

	# replace the preceding perl namespace hierarchy from the js namespace
	#foreach my $exposedNamespace (@{$self->search_path}) {
	my $exposedNamespace = $self->exposedNamespace();
	$moduleName =~ s/$exposedNamespace\:\://g;

    my @jsFunctionList = ();

	my $exposedMethods = $self->exposedMethodList();
    foreach my $methodName (@$exposedMethods) {
    	my $jsFunction = "\t$methodName: function(oArg, handler, objjself, objjselector) {\n\t\t return getMethod('$url/$moduleName/$methodName/', oArg, handler, objjself, objjselector);\n\t}";
        push (@jsFunctionList, $jsFunction);
    }


	my $buffer = 
         "var $moduleName = {\n\n" 
        . join(",\n", @jsFunctionList) 
        . "\n};\n\n";

    return $buffer;
}

# returns a string, containing the JSON representation of the given perl hash ref

sub returnJSON {
        my ($self, $h) = (@_);
       	my $r = $self->_r;

        if(defined($h)) {
        	my $jso = encode_json($h);
        	print STDERR "[jsonoutput] " . JSON->new->pretty->encode($h) ."\n" if $D;
        	$r->print($jso);
            #print JSON->new->pretty->encode($h);
        } else {
                $r->print(JSON->new->pretty->encode(
                                {
                               'status'  => 'NOK',
                               'message' => 'Function Returned No Value'
                                }
                ));
        }
}

# returns a hashref of the decoded JSON code read in from stdin 

sub fetchJSON {
	my $self = shift;
	my $buffer;
	my $json = {};
	if ($ENV{'REQUEST_METHOD'} eq "POST") {
		my $blen = read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
		if ($blen > 0) {
			$json = decode_json($buffer);
			print STDERR "decoded buffer ($json) into " . Dumper($json) . "\n" if $D;
		} else {
			# there was no JSON object POSTed
			print STDERR "ERROR: no JSON data available in POST\n" if $D;
		}
	}
	return $json;
}

1;
__END__

=head1 SEE ALSO

 http://www.json.org/JSONRequest.html

=head1 AUTHOR

Robert Colantuoni, E<lt>rgc@colantuoni.comE<gt>

Jeff Murphy, E<lt>jcmurphy@jeffmurphy.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Robert Colantuoni, Jeff Murphy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
