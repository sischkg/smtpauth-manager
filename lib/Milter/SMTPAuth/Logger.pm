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

has 'outputter'    => ( does => 'Milter::SMTPAuth::Logger::Outputter',
                        is  => 'rw',
                        required => 1 );
has 'formatter'    => ( does => 'Milter::SMTPAuth::Logger::Formatter',
                        is   => 'rw',
                        required => 1 );
has '_rrd'         => ( isa => 'Milter::SMTPAuth::Logger::RRDTool',
                        is  => 'rw',
                        default => sub { new Milter::SMTPAuth::Logger::RRDTool } );
has 'recv_address' => ( isa => 'Str',        is => 'rw', required => 1 );
has '_recv_socket' => ( isa => 'IO::Socket', is => 'rw' );
has 'queue_size'   => ( isa => 'Int',        is => 'ro', default => 20 );
has 'user'         => ( isa => 'Str',        is => 'ro', required => 1 );
has 'group'        => ( isa => 'Str',        is => 'ro', required => 1 );
has 'foreground'   => ( isa => 'Bool',       is => 'ro', default => 0 );
has 'pid_file'     => ( isa => 'Str',
			is   => 'ro',
                        default => '/var/run/smtpauth/log-collector.pid' );


sub BUILD {
    my ( $this ) = @_;

    openlog( 'smtpauth-log-collector',
	     'ndelay,pid,nowait',
	     'mail' );

    if ( ! $this->foreground ) {
        Milter::SMTPAuth::Utils::daemonize( $this->pid_file );
    }

    $this->_create_socket();
    set_effective_id( $this->user, $this->group );
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
        formatter    => new Milter::SMTPAuth::Looger::LTSV(),
        recv_address => 'unix:/var/run/smtpauth-logger.sock',
        user         => 'smtpauth-filter',
        group        => 'smtpauth-fliter',
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
	    my $peer = $this->_recv_socket->recv( $log_text, 10240 );
	    if ( defined( $peer ) ) {
		if ( $log_text eq q{} ) {
		    next LOG_ACCEPT;
		}

		my $message = thaw( $log_text );
		my $formatted_log = $this->formatter()->output( $message );
		$this->outputter->output( $formatted_log );
		$this->rrd->output( $message );
	    }
	    elsif ( $ERRNO == Errno::EINTR ) {
		next LOG_ACCEPT;
	    }
	    else {
		syslog( 'err', 'cannot recv(%s)', $ERRNO );
		last LOG_ACCEPT;
	    }
	}
    };
    if ( my $error = $EVAL_ERROR ) {
	syslog( 'err', 'caught error: %s', $error );
    }

    syslog( 'info', 'stopping' );
    $this->_recv_socket()->close();
    $this->outputter->close();

    if ( ! $this->foreground() ) {
        delete_pid_file( $this->pid_file() );
    }
}


sub _create_socket {
    my ( $this ) = @_;

    if ( $this->recv_address =~ m{\Ainet:(.+):(\d+)\z}xms ||
	 $this->recv_address =~ m{\A(\d+ \. \d+ \. \d+ \. \d+):(\d+)\z}xms ) {

	$this->_recv_socket( _create_inet_socket( $1, $2 ) );
    }
    elsif ( $this->recv_address =~ m{\Aunix:(.*)\z}xms ||
	    $this->recv_address =~ m{\A(/.+)\z}xms ) {
	$this->_recv_socket( _create_unix_socket( $1, $this->user, $this->group ) );
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    message => sprintf( qq{unknown socket address "%s"}, $this->recv_address ),
	);
    }
}



sub _create_inet_socket {
    my ( $address, $port ) = @_;

    return new IO::Socket::INET(
	LocalAddr => $address,
	LocalPort => $port,
	Proto     => SOCK_DGRAM
    );
}

sub _create_unix_socket {
    my ( $path, $user, $group ) = @_;

    if ( -e $path ) {
	unlink( $path );
    }

    my $socket = new IO::Socket::UNIX(
	Local  => $path,
	Type   => SOCK_DGRAM,
	Listen => 1,
    );
    if ( ! defined( $socket ) ) {
	Milter::SMTPAuth::LoggerError->throw(
	    error_message => sprintf( 'cannot open Logger recv socket "%s"(%s)', $path, $ERRNO ),
	);
    }

    change_mode( 0666, $path );
    change_owner( $user, $group, $path );

    return $socket;
}

1;

