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
use Milter::SMTPAuth::Logger::RRDTool;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;

has 'outputter'   => ( does => 'Milter::SMTPAuth::Logger::Outputter',
                       is  => 'rw',
                       required => 1 );
has 'formatter'   => ( does => 'Milter::SMTPAuth::Logger::Formatter',
                       is   => 'rw',
                       required => 1 );
has 'rrd'         => ( isa => 'Milter::SMTPAuth::Logger::RRDTool',
                       is  => 'rw',
                       default => sub { new Milter::SMTPAuth::Logger::RRDTool } );
has 'recv_path'   => ( isa => 'Str',                     is => 'rw', required => 1 );
has 'recv_socket' => ( isa => 'Maybe[IO::Socket::UNIX]', is => 'rw' );
has 'queue_size'  => ( isa => 'Int',                     is => 'ro', default => 20 );
has 'user'        => ( isa => 'Str',                     is => 'ro', required => 1 );
has 'group'       => ( isa => 'Str',                     is => 'ro', required => 1 );
has 'foreground'  => ( isa => 'Bool',                    is => 'ro',
                       default => 0 );
has 'pid_file'    => ( isa => 'Str',                     is => 'ro',
                       default => '/var/run/smtpauth/log-collector.pid' );

sub BUILD {
    my ( $this ) = @_;

    openlog( 'smtpauth-log-collector',
	     'ndelay,pid,nowait',
	     'mail' );

    if ( ! $this->foreground ) {
        Milter::SMTPAuth::Utils::daemonize( $this->pid_file );
    }

    if ( -e $this->recv_path() ) {
        unlink( $this->recv_path() );
    }

    set_effective_id( $this->user(), $this->group() );

    my $recv_socket = new IO::Socket::UNIX( Type   => SOCK_DGRAM,
                                            Local  => $this->recv_path );
    if ( ! defined( $recv_socket ) ) {
	my $error = sprintf( 'cannot open Logger recv socket "%s"( %s )',
			     $this->recv_path,
                             $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }

    if ( chmod( 0666, $this->recv_path() ) <= 0 ) {
        $recv_socket->close();
	my $error = sprintf( 'cannot chmod recv socket "%s"( %s )',
			     $this->recv_path,
			     $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
    }
    $this->recv_socket( $recv_socket );
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
        formatter => new Milter::SMTPAuth::Looger::File(),
        recv_path => '/var/run/smtpauth-logger.sock',
        user      => 'smtpauth-filter',
        group     => 'smtpauth-fliter',
    );

    my $message = new Milter::SMTPAuth::Message;
    ...

    $logger->output( $message );

    # log client
    use Milter::SMTPAuth::Logger::Client;

    my $logger = new Milter::SMTPAuth::Logger::Client(
        recv_path => '/var/run/smtpauth-logger.sock'
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

=item * recv_path

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

    eval {
	syslog( 'info', 'started' );
      LOG_ACCEPT:
	while ( $is_continue ) {
	    my $log_text;
	    my $peer = $this->recv_socket->recv( $log_text, 10240 );
	    if ( defined( $peer ) ) {
		if ( $log_text eq q{} ) {
		    next LOG_ACCEPT;
		}

		my $message = thaw( $log_text );
		my $formatted_log = $this->formatter()->output( $message );
		$this->outputter->output( $formatted_log );
		$this->rrd->output( $message );
	    } elsif ( $ERRNO == Errno::EINTR ) {
		next LOG_ACCEPT;
	    } else {
		syslog( 'err', 'cannot recv(%s)', $ERRNO );
		last LOG_ACCEPT;
	    }
	}
    };
    if ( my $error = $EVAL_ERROR ) {
	syslog( 'err', 'caught error: %s', $error );
    }

    syslog( 'info', 'stopping' );
    $this->recv_socket()->close();
    $this->outputter->close();

    if ( ! $this->foreground() ) {
        delete_pid_file( $this->pid_file() );
    }
}

1;

