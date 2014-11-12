package Milter::SMTPAuth::Limit::NetworkWeight;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Utils::ACL;

has '_weight_of' => ( isa     => 'Milter::SMTPAuth::Utils::ACL',
		      is      => 'rw',
		      default => sub { new Milter::SMTPAuth::Utils::ACL });

sub load_config {
    my $this = shift;
    my ( $config_data ) = @_;

    if ( ! exists( $config_data->{network} ) ) {
	return;
    }

    foreach my $acl ( @{ $config_data->{network} } ) {
	foreach my $key ( qw( network weight ) ) {
	    if ( ! exists( $acl->{$key} ) ) {
		Milter::SMTPAuth::ArgumentError->throw(
		    error_message => qq{weight entry must have "$key".},
		);
	    }
	}

	my $result = match_ip_address( $acl->{network} );
	if ( ! defined( $result ) ) {
	    Milter::SMTPAuth::ArgumentError->throw(
		error_message => sprintf( q{invalid network address "%s".}, $acl->{network} ),
	    );
	}
	my $network_address = $result->{address};
	my $bit_length      = $result->{bit_length};

	$this->_weight_of->add(
	    new Milter::SMTPAuth::Utils::ACLEntry(
		network    => $network_address,
		bit_length => $bit_length,
		name       => sprintf( "%s/%s: %f",
				       $network_address,
				       $bit_length,
				       $acl->{weight} ),
		value      => $acl->{weight},
	    )
	);
    }
}


sub get_weight {
    my $this = shift;
    my ( $message ) = @_;

    my $address = $message->client_address();
    if ( ! defined( $address ) ) {
	return 1;
    }
    my $acl_entry = $this->_weight_of->match( $address );
    if ( $acl_entry ) {
	syslog( 'debug', q{IP address "%s" is matched %s.}, $address, $acl_entry->name() );
	return $acl_entry->value();
    }
    else {
	syslog( 'debug', q{IP address "%s" is not matched.}, $address );
	return 1;
    }
}

1;

