# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger;

use Moose;
use English;
use IO::Socket::UNIX;
use Sys::Syslog;
use Storable qw( thaw );
use Milter::SMTPAuth::Logger::Outputter;
use Milter::SMTPAuth::Logger::Formatter;
use Milter::SMTPAuth::Logger::File;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;

has 'outputter'      => ( does => 'Milter::SMTPAuth::Logger::Outputter',
                          is  => 'rw',
                          required => 1 );
has 'formatter'      => ( does => 'Milter::SMTPAuth::Logger::Formatter',
                          is   => 'rw',
                          required => 1 );
has 'listen_path'    => ( isa => 'Str',                     is => 'rw', required => 1 );
has 'listen_socket'  => ( isa => 'Maybe[IO::Socket::UNIX]', is => 'rw' );
has 'queue_size'     => ( isa => 'Int',                     is => 'ro', default => 20 );
has 'user'           => ( isa => 'Str',                     is => 'ro', required => 1 );
has 'group'          => ( isa => 'Str',                     is => 'ro', required => 1 );

sub BUILD {
    my ( $this ) = @_;

    if ( -e $this->listen_path() ) {
      unlink( $this->listen_path() );
    }

    set_effective_id( $this->user(), $this->group() );

    my $listen_socket = new IO::Socket::UNIX( Type   => SOCK_DGRAM,
					      Local  => $this->listen_path,
					      Listen => $this->queue_size );
    if ( ! defined( $listen_socket ) ) {
	my $error = sprintf( 'cannot open Logger listen socket "%s"( %s )',
			     $this->listen_path,
                             $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }

    if ( chmod( 0666, $this->listen_path() ) <= 0 ) {
        $listen_socket->close();
	my $error = sprintf( 'cannot chmod listen socket "%s"( %s )',
			     $this->listen_path,
			     $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }
    $this->listen_socket( $listen_socket );
}


=head1 NAME

Milter::SMTPAuth::Logger - Milter::SMTPAuth::Filter statistics log module.


=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth::Logger;
    use Milter::SMTPAuth::Logger::File;

    my $logger = new Milter::SMTPAuth::Logger(
	    outputter    => new Milter::SMTPAuth::Logger::File(
	        logfile_name => '/var/log/smtpauth.maillog'
        ),
        formatter   => new Milter::SMTPAuth::Looger::File(),
        listen_path => '/var/run/smtpauth-logger.sock',
        user        => 'smtpauth-filter',
        group       => 'smtpauth-fliter',
    );

    my $message = new Milter::SMTPAuth::Message;
    ...

    $logger->output( $message );

    # log client
    use Milter::SMTPAuth::Logger::Client;

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_path => '/var/run/smtpauth-logger.sock'
    );
    my $message = new Milter::SMTPAuth::Message;
    ...
    $logger->send( $message );


=head1 SUBROUTINES/METHODS

=head2 new

create Logger instance. 

=over 4

=item * outputter

subclass of Milter::SMTPAuth::Logger::Outputter.

=item * listen_path

path of UNIX Domain Socket for receive log message.

=back

=cut

my $is_continue = 1;


$SIG{USR1} = sub {
    $is_continue = 0;
};

$SIG{USR2} = sub {
    exit( 0 );
};

$SIG{PIPE} = 'IGNORE';

=head2 run

run service.

=cut

sub run {
    my ( $this ) = @_;

    openlog( 'smtpauth-log-collector',
	     'ndelay,pid,nowait',
	     'mail' );

    syslog( 'info', 'started' );
 LOG_ACCEPT:
    while ( $is_continue ) {
        my $log_text;
        if (  $this->listen_socket->recv( $log_text, 10240 ) ) {
            if ( $log_text eq q{} ) {
                next LOG_ACCEPT;
            }

            my $message = thaw( $log_text );
            my $formatted_log = $this->formatter()->output( $message );
            $this->outputter->output( $formatted_log );
        }
	elsif ( $ERRNO == Errno::EINTR ) {
	    next LOG_ACCEPT;
	}
	else {
	    syslog( 'err', 'cannot accept (%s)', $ERRNO );
	    last LOG_ACCEPT;
	}
    }

    syslog( 'info', 'stopping' );
    $this->listen_socket()->close();
    $this->outputter->close();
}

1;

