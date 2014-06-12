# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::Client;

use Moose;
use English;
use Sys::Syslog;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Storable qw( nfreeze );
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;

has 'listen_address' => ( isa => 'Str', is => 'rw', required => 1 );

=head1 NAME

Milter::SMTPAuth::Logger::Client - Send Milter::SMTPAuth::Filter statistics log.

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Logger::Client;

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_address => 'unix:/var/run/smtpauth-filter-logger',
    );

    my $message = new Milter::SMTPAuth::Message;
    $logger->send( $message );


=head1 SUBROUTINES/METHODS

=head2 new

create Logger instance.

=head2 send

send log to server.

=cut

sub send {
    my $this = shift;
    my ( $message ) = @_;

    my $socket_params = Milter::SMTPAuth::SocketParams::parse_socket_address( $this->listen_address );
    my $socket;
    if ( $socket_params->is_inet ) {
	$socket = new IO::Socket::INET(
	    PeerAddr => $socket_params->address,
	    PeerPort => $socket_params->port,
	    Proto    => 'udp',
	    Type     => SOCK_DGRAM,
	);
    }
    else {
	$socket = new IO::Socket::UNIX(
	    Type => SOCK_DGRAM,
	    Peer => $socket_params->address,
	);
    }
    if ( ! defined( $socket ) ) {
	my $error = sprintf( 'cannot open Logger socket "%s"(%s)',
			     $this->listen_address,
			     $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }

    my $data = nfreeze( $message );
    if ( ! $socket->print( $data ) ) {
	$socket->close();
	my $error = sprintf( 'cannot output log to socket(%s).', $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }

    $socket->close();
}

1;

