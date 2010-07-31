package Net::WebFunk::API::Exposed::Template;
use Moose;
use JSON;
use Data::Dumper;

extends 'Net::WebFunk::API';
has '_r' => (is => 'rw', isa => 'Apache2::RequestRec', required => 1);

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
	my $self = shift;

	$self->debug();

	my $perlhash = $self->fetchJSON();

	use Data::Dumper;
	my $msg = "You sent: " . Dumper($perlhash);

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

