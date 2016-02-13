package Milter::SMTPAuth::Limit::NetworkWeight;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Utils::ACL;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Limit::Role;

with 'Milter::SMTPAuth::Limit::Role';

has '_weight_of' => (
    isa     => 'Milter::SMTPAuth::Utils::ACL',
    is      => 'rw',
    default => sub { new Milter::SMTPAuth::Utils::ACL } );

sub load_config {
    my $this = shift;
    my ( $config_data ) = @_;

    if ( !exists( $config_data->{network} ) ) {
        return;
    }

    foreach my $acl ( @{ $config_data->{network} } ) {
        foreach my $key ( qw( network weight ) ) {
            if ( !exists( $acl->{$key} ) ) {
                Milter::SMTPAuth::ArgumentError->throw( error_message => qq{Weight entry must have "$key".}, );
            }
        }

        my $network = Milter::SMTPAuth::Utils::ACLEntry::check_ip_address( $acl->{network} );
        if ( !defined( $network ) ) {
            Milter::SMTPAuth::ArgumentError->throw(
                error_message => sprintf( q{Invalid network address "%s".}, $acl->{network} ), );
        }

        $this->_weight_of->add(
            new Milter::SMTPAuth::Utils::ACLEntry(
                address => $network,
                name    => sprintf( "%s: %f", $acl->{network}, $acl->{weight} ),
                value   => $acl->{weight},
            ) );
    }
}

sub get_weight {
    my $this = shift;
    my ( $message ) = @_;

    my $address = $message->client_address();
    if ( !defined( $address ) ) {
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

