package Net::WebFunk::API::Apache2;

use Net::WebFunk::API;
use Apache2::Request;
use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::Const;
use Apache2::URI;
use JSON;

=head1 NAME

Net::WebFunk::API::Apache2 - Apache2 Module for generating the JS API from exported modules

=head1 SYNOPSIS

Put the following lines into a new file: /etc/httpd/conf.d/NetJS.conf

 <Location /api>
      SetHandler perl-script
      PerlResponseHandler Net::WebFunk::API::Apache2
  </Location>

That will make the JS api available at /api on your webserver.

=head1 DESCRIPTION

This Apache2 module will take incoming http requests to whatever API location
you specify and it will provide the JS API for the exported perl modules.
It also generates a hierarchy through which you can call the functions.
For example, the functionPublic method within Net::WebFunk::API::Exposed::Template
would be available at: /api/Template/functionPublic

=cut

sub handler {
	my $r = shift;

	my $exppath = $r->dir_config('WebFunkRoot');
	if (defined($exppath)) {
		push @INC, $exppath unless grep(/^$exppath$/,@INC) > 0;
	}
	my $api = new Net::WebFunk::API(_r => $r);
	$api->setExposedNamespace($r->dir_config('WebFunkExpRoot'));

	# if you enter just the URL into a browser, safari and FF will send over a list of accepted types,
	# one of which is text/html. IE, ofcourse, doesnt do that. WTH. All three browsers, however, 
	# send over just "*/*" for <script> tags. So if we get "*/*" or "application/javascript" then send
	# back JS, otherwise send back html doc. more IE stupidity: if you type in the URL you get a full
	# list of accepted types, if you hit 'reload' (even shift-reload) you get just "*/*". I guess IE users
	# are SOL for doc.
	
	my $acceptheader = $ENV{'HTTP_ACCEPT'};
	$acceptheader =~ s/\s+//g;
	my @http_accept = split(',', (split(';', $acceptheader))[0]);
	
	# if accept is "*/*" or contains "application/javascript" then then client wants javascript
	# if accept is "application/perl" the client wants perl
	# otherwise the client wants documentation
	
	#my $wantdoc   = (grep (/^text.html$/, @http_accept)) ? 1 : 0;  # ideally, but not in IE apparently
	my $wantperl = (grep /^application.perl$/, @http_accept) ? 1 : 0;
	my $wantjs   = (grep /^\*.\*$/, @http_accept) || (grep /^application.javascript$/, @http_accept);
	#my $wantdoc = ((!$wantperl) && (($#http_accept == 0) && ($http_accept[0] eq "application/javascript") || ($http_accept[0] eq "*/*"))) ? 0 : 1;
	my $wantdoc = (!$wantperl && !$wantjs) ? 1 : 0;
	
	#print STDERR $r->uri . " accept: $acceptheader \n";
	print STDERR $r->uri . " client wants any of: " . join(', ', @http_accept) . " wantdoc:$wantdoc wantperl:$wantperl wantjs:$wantjs\n";
	
	# if the top level (typically http://server/api or http://server/api/) is called
	# then this code handles outputting all of the exposed modules or a table
	# of contents for documentation
	
	if ($wantdoc) {
		$r->content_type('text/html');
	} else {
	  	$r->content_type('text/plain'); # maybe send application/javascript or whatever? 
	}

	if($r->path_info =~ /^\/*$/) {
		if ($wantdoc) {
			my $baseclass = $r->dir_config('WebFunkExpRoot');
			$baseclass =~ s/;/, /g;
			$r->print("<style>
			PRE {border:2px dashed #8888AA; background: #DDDDFF; margin-left: 30px; padding: 10px; } 
			TABLE {border: none; width: 85%; margin-left: 30px;}
			TD.col1 {width: 10%; }
			TD.col2 {border-bottom: 2px solid black; }
			</style>");
			$r->print("<h1>Package: $baseclass</h1>");
			$r->print("<h2>Exposed Methods</h2><table>");
			foreach my $exposedModule ($api->exposed()) {
        		my $module = new $exposedModule(_r => $r);
        		my $exmod = ref($module);
        		$exmod =~ s/^${baseclass}:://;
        		my $url = $r->construct_url;
        		my $mdesc = $module->mydoc(1);
        		$r->print('<tr><td class="col1"><a href="' . $url . "/$exmod/\">" . "$exmod</td><td class='col2'>$mdesc</td></tr></a><br/>");
			}
       		$r->print("</table><h2>Javascript Header</h2>When connecting using Javascript, specify an Accept header of <code>application/javascript</code> (if using XHR or just use a <code>&lt;script&gt;</code> tag otherwise) to receive the following binding code. Portions of the following code are programmatically generated, so you shouldn't cut-n-paste it. It's presented here for reference. <p/><pre>".$api->JSHeader);
			foreach my $exposedModule ($api->exposed()) {
        		my $module = new $exposedModule(_r => $r);
				$r->print($module->JSStub($r->construct_url));
			}
			$r->print("</pre><P/>");
			$r->print("<h2>Perl Header</h2>When connecting using a Perl script, specify an Accept header of <code>application/perl</code> to receive the following binding code. Portions of the following code are programmatically generated, so you shouldn't cut-n-paste it. It's presented here for reference. <p/><pre>".$api->PerlHeader);
			foreach my $exposedModule ($api->exposed()) {
        		my $module = new $exposedModule(_r => $r);
				$r->print($module->PerlStub($r->construct_url));
			}
			$r->print("</pre><P/>");
		} else {
			$r->print($api->JSHeader) if $wantjs;
			$r->print($api->PerlHeader) if $wantperl;
			foreach my $exposedModule ($api->exposed()) {
        		my $module = new $exposedModule(_r => $r);
				$r->print($module->JSStub($r->construct_url)) if $wantjs;
				$r->print($module->PerlStub($r->construct_url)) if $wantperl;
			}
		}
		return Apache2::Const::OK;
	}

	my $calledModule = '';
	my $calledMethod = '';
	
	# if we're here, then we've received a specific object or method in the URL
	# such as http://server/api/Object/ or http://server/api/Object/method1/
	# and we should output only the code that pertains to that object or method
	# or the doc for those if applicable (based on HTTP_ACCEPT)
	
	if($r->path_info =~ /^\/([A-Za-z0-9_]+)\/$/) {
		$calledModule = $1;
	}

	if($r->path_info =~ /^\/([A-Za-z0-9_]+)\/([A-Za-z0-9_]+)\/$/) {
		$calledModule = $1;	
		$calledMethod  = $2;	
	}

	if($calledModule || $calledMethod) {
		
		my $exposedNamespace = $api->exposedNamespace();
		$calledModule =  $exposedNamespace . '::' . $calledModule;

		# move this check into API, $api->moduleExists($calledModule);
		my @a = $api->exposed();
		my @m = grep(/^$calledModule$/, @a);

		if($#m < 0) {
			print STDERR "client requested invalid module ". $r->path_info . "\n";
			if ($wantdoc) {
				$r->print("Requested module does not exist.");
				return Apache2::Const::OK;
			}
			return Apache2::Const::HTTP_NOT_IMPLEMENTED;
		}

		# it exists, so initialize it and check for func

        my $module = new $calledModule(_r => $r);

		if($calledMethod ne '') {
			# move this check into API, $module->methodExists($calledMethod);
			# moose might have a much easier way to check for funct.. 'exists'?
			my $exposedMethods = $module->exposedMethodList();
			my @n = grep(/^$calledMethod$/, @$exposedMethods);

			if($#n < 0) {
				print STDERR "client requested invalid method ". $r->path_info . "\n";
				if ($wantdoc) {
					$r->print("Requested method does not exist. Available methods for this object: <P/>");
					$r->print(join("<BR/>", @$f));
					return Apache2::Const::OK;
				}
				return Apache2::Const::HTTP_NOT_IMPLEMENTED;
			}

			# call the function, pass in the apache req object here or on module init?
			# i think module init would be better
			$module->$calledMethod(Apache2::Request->new($r));
		} else {
			# module but no method, print js for this module only
			if ($wantdoc) {
		        my $methodMap = $module->meta->_full_method_map;
#				if (!exists ($methodMap->{'mydoc'})) {
#					print STDERR "The client wants doc for this module, but you forgot the _mydoc routine. " . $r->path_info . "\n";
#					$r->print("Documentation unavailable (_mydoc missing)");
#				} else {
					$r->print($module->mydoc(0));
#				}
			} else {	
				$r->print($api->JSHeader) if $wantjs;
				$r->print($api->PerlHeader) if $wantperl;
				$r->print($module->JSStub($r->construct_url)) if $wantjs;
				$r->print($module->PerlStub($r->construct_url)) if $wantperl;
			}
			return Apache2::Const::OK;
		}
	} 

	return Apache2::Const::HTTP_NOT_IMPLEMENTED;
}

1;
__END__


=head1 SEE ALSO

 Net::WebFunk::API

=head1 AUTHOR

Robert Colantuoni, E<lt>rgc@colantuoni.comE<gt>

Jeff Murphy, E<lt>jcmurphy@jeffmurphy.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Robert Colantuoni, Jeff Murphy

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
