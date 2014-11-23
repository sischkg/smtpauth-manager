# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::Client;

use Moose;
use English;
use Sys::Syslog;
use Net::INET6Glue;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Storable qw( nfreeze );
use Readonly;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;

Readonly::Scalar my $SEND_LOG_RETRY => 3;

has '_logger_socket' => ( isa => 'IO::Socket',                     is => 'rw', required => 1 );
has '_socket_params' => ( isa => 'Milter::SMTPAuth::SocketParams', is => 'ro', required => 1 );


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
    ...

=head1 SUBROUTINES/METHODS

=head2 new

create Logger instance.

=head2 send

send log to server.

=cut

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my @args  = @_;

    my $args_ref;
    if ( @args == 1 && ref $args[0] ) {
	# contstructor args is Hash reference.
	$args_ref = $args[0];
    }
    elsif ( @args % 2 == 0 ) {
	my %args = @args;
	$args_ref = \%args;
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "Milter::SMTPAuth::Logger::Client::new has Hash reference or list arguments"
	);
    }
    if ( ! $args_ref->{logger_address} ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "Milter::SMTPAuth::Filter::new must has logger_address option."
	);
    }

    my $socket_params = Milter::SMTPAuth::SocketParams::parse( $args_ref->{logger_address} );
    my $socket = connect_log_socket( $socket_params );

    if ( ! defined( $socket ) ) {
	my $error = sprintf( 'cannot open Logger socket "%s"(%s)',
			     $args_ref->{listen_address},
			     $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }

    return $class->$orig( {
	_logger_socket => $socket,
	_socket_params => $socket_params,
    } );
};


sub DEMOLISH {
    my $this = shift;
    $this->_logger_socket->close();
}

sub send {
    my $this = shift;
    my ( $message ) = @_;

    my $data = nfreeze( $message );
    for ( my $i = 0 ; $i < $SEND_LOG_RETRY ; ++$i ) {
	if ( $this->_logger_socket->print( $data ) ) {
	    last;
	}
	syslog( 'err', 'cannot output log to socket(%s).', $ERRNO );
	$this->_logger_socket()->close();
	$this->_logger_socket( connect_log_socket( $this->_socket_params() ) );
    }

}


sub connect_log_socket {
    my ( $socket_params ) = @_;

    my $socket;
    my @errors;

    for ( my $i = 0 ; $i < $SEND_LOG_RETRY ; ++$i ) {
	if ( $socket_params->is_inet() ) {
	    $socket = new IO::Socket::INET(
		PeerAddr => $socket_params->address,
		PeerPort => $socket_params->port,
		Proto    => 'udp',
		Type     => SOCK_DGRAM,
	    );
	} else {
	    $socket = new IO::Socket::UNIX(
		Type => SOCK_DGRAM,
		Peer => $socket_params->address,
	    );
	}
	if ( $socket ) {
	    return $socket;
	}
	sleep( 1 );
    }

    Milter::SMTPAuth::LoggerError->throw( error_message => join( " ,", @errors ) );
}

1;

