
use strict;
use warnings;
use Test::More qw( no_plan );
use Math::BigInt;
use Milter::SMTPAuth::Utils;
use Readonly;

sub test_socket_params {
    my ( $socket_address_str, $expected_type, $other_test ) = @_;

    my $param = Milter::SMTPAuth::SocketParams::parse( $socket_address_str, $expected_type );
    if ( $expected_type == Milter::SMTPAuth::SocketParams::UNIX ) {
        ok( $param->is_unix(),   "$socket_address_str is unix socket" );
        ok( !$param->is_inet(),  "$socket_address_str is not inet socket" );
        ok( !$param->is_inet6(), "$socket_address_str is not inet6 socket" );
    }
    elsif ( $expected_type == Milter::SMTPAuth::SocketParams::INET ) {
        ok( !$param->is_unix(),  "$socket_address_str is not unix socket" );
        ok( $param->is_inet(),   "$socket_address_str is inet socket" );
        ok( !$param->is_inet6(), "$socket_address_str is not inet6 socket" );
    }
    else {
        ok( !$param->is_unix(), "$socket_address_str is not unix socket" );
        ok( !$param->is_inet(), "$socket_address_str is not inet socket" );
        ok( $param->is_inet6(), "$socket_address_str is inet6 socket" );
    }

    if ( $other_test ) {
        $other_test->( $param );
    }
}

test_socket_params(
    "127.0.0.1:6000",
    Milter::SMTPAuth::SocketParams::INET,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "127.0.0.1", "127.0.0.1:6000 address is 127.0.0.1" );
        is( $param->port(),    6000,        "127.0.0.1:6000 port is port" );
    } );

test_socket_params(
    "inet:127.0.0.1:6000",
    Milter::SMTPAuth::SocketParams::INET,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "127.0.0.1", "inet:127.0.0.1:6000 address is 127.0.0.1" );
        is( $param->port(),    6000,        "inet:127.0.0.1:6000 port is port" );
    } );

test_socket_params(
    "inet:localhost.localdomains:6000",
    Milter::SMTPAuth::SocketParams::INET,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "localhost.localdomains",
            "inet:localhost.localdomains:6000 address is localhost.localdomains" );
        is( $param->port(), 6000, "inet:localhost.localdomains:6000 port is port" );
    } );

test_socket_params(
    "inet6:::1:6000",
    Milter::SMTPAuth::SocketParams::INET6,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "::1", "inet6:::1:6000 address is ::1" );
        is( $param->port(),    6000,  "inet6:::1:6000 port is port" );
    } );

test_socket_params(
    "unix:/var/run/filter.sock",
    Milter::SMTPAuth::SocketParams::UNIX,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "/var/run/filter.sock", "unix:/var/run/filter.sock address is /var/run/filter.sock" );
    } );

test_socket_params(
    "/var/run/filter.sock",
    Milter::SMTPAuth::SocketParams::UNIX,
    sub {
        my ( $param ) = @_;
        is( $param->address(), "/var/run/filter.sock", "/var/run/filter.sock address is /var/run/filter.sock" );
    } );

