# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::Client;

use Moose;
use English;
use IO::Socket::UNIX;
use Storable qw( nfreeze );
use Milter::SMTPAuth::Exception;

has 'listen_path' => ( isa => 'Str', is => 'rw', required => 1 );

=head1 NAME

Milter::SMTPAuth::Logger::Client - Send Milter::SMTPAuth::Filter statistics log.

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Logger::Client;

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_path => '/var/run/smtpauth-filter-logger',
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

    my $socket = new IO::Socket::UNIX( Type => SOCK_DGRAM,
				       Peer => $this->listen_path );
    if ( ! defined( $socket ) ) {
	my $error = sprintf( 'cannot open Logger socket "%s"(%s)',
			     $this->listen_path,
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

