
package Milter::SMTPAuth::Limit::GeoIPWeight;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Utils::GeoIP;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Limit::Role;

with 'Milter::SMTPAuth::Limit::MessageLimitRole';

has 'geoip'      => ( isa => 'Object',         is => 'ro', required => 1 );
has '_weight_of' => ( isa => 'HashRef[Float]', is => 'ro', default => sub { {} } );

sub load_config {
    my $this = shift;
    my ( $config_data ) = @_;

    if ( ! exists( $config_data->{country} ) ) {
	return;
    }

    foreach my $country ( @{ $config_data->{country} } ) {
	foreach my $key ( qw( code weight ) ) {
	    if ( ! exists( $country->{$key} ) ) {
		Milter::SMTPAuth::ArgumentError->throw(
		    error_message => qq{weight entry must have "$key".},
		);
	    }
	}

	$this->_weight_of->{ uc( $country->{code} ) } = $country->{weight};
	syslog( 'debug', "registerd weight; code: %s, weight: %f", $country->{code}, $country->{weight} );
    }
}

sub get_weight {
    my $this = shift;
    my ( $message ) = @_;

    my $code   = $this->geoip()->get_country_code( $message->client_address() );
    my $weight = $this->_weight_of->{ $code };
    if ( $weight ) {
	return $weight;
    }
    else {
	return 1;
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
