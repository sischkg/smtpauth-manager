package Milter::SMTPAuth::Limit::AuthIDWeight;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Utils;

has '_weight_of' => ( isa     => 'HashRef',
		      is      => 'rw',
		      default => sub { {} });

sub load_config {
    my $this = shift;
    my ( $config_data ) = @_;

    if ( ! exists( $config_data->{auth_id} ) ) {
	return;
    }

    foreach my $weight ( @{ $config_data->{auth_id} } ) {
	foreach my $key ( qw( auth_id weight ) ) {
	    if ( ! exists( $weight->{$key} ) ) {
		Milter::SMTPAuth::ArgumentError->throw(
		    error_message => qq{weight entry must have "$key".},
		);
	    }
	}

	$this->_weight_of->{ $weight->{auth_id} } = $weight->{weight};
    }
}


sub get_weight {
    my $this = shift;
    my ( $message ) = @_;

    my $auth_id = $message->auth_id();
    if ( ! defined( $auth_id ) ) {
	return 1;
    }
    my $weight = $this->_weight_of->{$auth_id};
    if ( $weight ) {
	syslog( 'debug', q{Auth ID "%s" is matched.}, $auth_id );
	return $weight;
    }
    else {
	syslog( 'debug', q{Auth ID "%s" is not matched.}, $auth_id );
	return 1;
    }
}

1;

