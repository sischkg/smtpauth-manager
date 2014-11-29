
package Milter::SMTPAuth::Utils::GeoIP;

use Moose;
use English;
use Readonly;
use Geo::IP;
use Net::IP;
use Data::Dumper;

Readonly::Scalar my $GEOIP_FLAGS => ( GEOIP_MEMORY_CACHE | GEOIP_CHECK_CACHE );

has geoip => ( isa => 'Geo::IP', is => 'rw', required => 1 );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig( @_ );

    my $geoip;
    if ( $args->{database_filename} ) {
        eval {
            $geoip = Geo::IP->open( $args->{database_filename}, $GEOIP_FLAGS );
        };
        if ( my $error = $EVAL_ERROR ) {
            Milter::SMTPAuth::ArgumentError->throw( "cannot load GeoIP database $args->{database_filename}." );
        }
    }
    else {
        eval {
            $geoip = Geo::IP->new( $GEOIP_FLAGS );
        };
        if ( my $error = $EVAL_ERROR ) {
            Milter::SMTPAuth::ArgumentError->throw( "cannot load GeoIP database." );
        }
    }

    return { geoip => $geoip };
};


sub get_country_code {
    my $this = shift;
    my ( $address ) = @_;

    my $ip = new Net::IP( $address );
    if ( ! defined( $ip ) ) {
        return undef;
    }
    elsif ( $ip->version == 4 ) {
        return $this->geoip()->country_code_by_addr( $address );
    }
    else {
        return $this->geoip()->country_code_by_addr_v6( $address );
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
