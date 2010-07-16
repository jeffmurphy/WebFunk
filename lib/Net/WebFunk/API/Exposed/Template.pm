package Net::WebFunk::API::Exposed::Template;
use Moose;
use JSON;
use Data::Dumper;

extends 'Net::WebFunk::API';

=head1 NAME

Net::WebFunk::API::Exposed::Template - A boilerplate for starting a new library with an exposed javascript API

=head1 DESCRIPTION

Use this as a starting point for new exposed libaries

=head1 METHODS

Methods with an underscore prefix are not callable remotely.

=cut

=over

=item methodPublic(anyparam)

This method will return a status of OK and whatever was passed to it. 

=back

=cut

sub methodPublic {
	my ($self, $r) = (@_);

	# this method can be called from the JS API

	my $buffer;
	my $json;
	if ($ENV{'REQUEST_METHOD'} eq "POST") {
		my $blen = read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
		if ($blen > 0) {
			$json = decode_json($buffer);
			print STDERR "decoded buffer into " . Dumper($json) . "\n";
		} else {
			# there was no JSON object POSTed
			print STDERR "ERROR: no JSON data available in POST\n";
		}
	}

	my $msg = "You sent: $buffer";

	$self->returnJSON(
			{
				'status'  => 'OK',
                'message' => $msg
           	}
		);
}

=over

=item _methodPrivate(anyparam)

This is a private method. It's not available via RPC.

=back

=cut


# if you don't want private methods to appear in the published documentation,
# don't use Pod as shown above and instead just use comments like these.

sub _methodPrivate {
	my ($self) = (@_);

	# this method can't be called from the JS API

	return;

}

sub _mydoc {
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


#Discover the path to our module given our package. Thought about looking for 
#
#	/Net.JS.API/
#
#iteratively, but not thrilled about that overhead for each API call. Instead we
#construct the exact package name
#
#	Net/JS/API.pm
#
#and test directly. Currently we assume Unix path seps. Havent checked to seek 
#if Perl on Windows puts Net\JS\API.pm into the INC hash. 


sub _mypath {
	my $self = shift;
	my $pkg = ref($self) . ".pm";
	$pkg =~ s/::/\//g; # FIX unix only
	return $INC{$pkg} if (exists $INC{$pkg});
	return undef;
}

# used to validate if the caller has given us the minimum required fields
#       my @repParams = qw(username password);
#		if (_requiredfields(\@reqParams, $json) == 1) {
#          do stuff...
#       } else {
#          error invalid params
#       }

sub _requiredfields {
	my $farray = shift;
	my $ahash  = shift;
	
	if (ref($farray) eq "ARRAY") {
		if ($#$farray > -1) {
			foreach my $fname (@$farray) {
				return 0 if !exists $ahash->{$fname};
			}
			return 1;
		}
	}
	return 0;
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

