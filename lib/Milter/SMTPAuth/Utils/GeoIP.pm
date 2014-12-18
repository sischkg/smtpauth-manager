
package Milter::SMTPAuth::Utils::GeoIP;

use Moose;
use English;
use version;
use Sys::Syslog;
use Readonly;
use Geo::IP;
use Net::IP;
use Data::Dumper;

Readonly::Scalar my $GEOIP_FLAGS => ( GEOIP_MEMORY_CACHE | GEOIP_CHECK_CACHE );

has geoip_v4 => ( isa => 'Maybe[Geo::IP]', is => 'rw' );
has geoip_v6 => ( isa => 'Maybe[Geo::IP]', is => 'rw' );

sub load_data {
    my ( $data_filename ) = @_;

    if ( ! $data_filename ) {
	syslog( 'debug', 'Milter::SMTPAuth::Utils::GeoIP::load_data data_filename not specified.' );
	return undef;
    }

    my $geoip = eval {
	Geo::IP->open( $data_filename, $GEOIP_FLAGS );
    };
    if ( my $error = $EVAL_ERROR ) {
	Milter::SMTPAuth::ArgumentError->throw( "cannot load GeoIP database $data_filename." );
    }

    return $geoip;
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig( @_ );

    my %new_args;
    my $geoip_v4 = load_data( $args->{database_filename_v4} );

    # IPv6を扱ううことができるGeo::IPは、バージョン1.39以降である。
    my $geoip_v6 = undef;
    my $geoip_version = new version( $Geo::IP::VERSION );
    if ( $geoip_version gt "1.38" ) {
	$geoip_v6 = load_data( $args->{database_filename_v6} );
    }

    syslog( 'info', 'loaded geoip_v4 %s', $geoip_v4 ? 'OK' : 'NG' );
    syslog( 'info', 'loaded geoip_v6 %s', $geoip_v6 ? 'OK' : 'NG' );

    return {
	geoip_v4 => $geoip_v4,
	geoip_v6 => $geoip_v6,
    };
};


sub get_country_code {
    my $this = shift;
    my ( $address ) = @_;

    my $ip = new Net::IP( $address );
    if ( ! defined( $ip ) ) {
        return undef;
    }
    elsif ( $ip->version == 4 && $this->geoip_v4() ) {
        return $this->geoip_v4()->country_code_by_addr( $address );
    }
    elsif ( $ip->version == 6 && $this->geoip_v6() ) {
        return $this->geoip_v6()->country_code_by_addr_v6( $address );
    }
    return undef;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
