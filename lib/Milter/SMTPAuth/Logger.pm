# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger;

use Moose;
use English;
use Net::INET6Glue;
use IO::Socket::INET;
use IO::Socket::UNIX;
use Sys::Syslog;
use Scalar::Util qw(looks_like_number);
use Storable qw( thaw );
use Milter::SMTPAuth::Logger::Outputter;
use Milter::SMTPAuth::Logger::Formatter;
use Milter::SMTPAuth::Logger::File;
use Milter::SMTPAuth::Logger::RRDTool;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Utils::GeoIP;
use Milter::SMTPAuth::Limit;

has 'outputter'    => ( does     => 'Milter::SMTPAuth::Logger::Outputter',
                        is       => 'rw',
                        required => 1 );
has 'formatter'    => ( does     => 'Milter::SMTPAuth::Logger::Formatter',
                        is       => 'rw',
                        required => 1 );
has '_rrd'         => ( isa      => 'Milter::SMTPAuth::Logger::RRDTool',
                        is       => 'rw',
                        default  => sub { new Milter::SMTPAuth::Logger::RRDTool } );
has '_recv_socket' => ( isa => 'IO::Socket', is => 'rw', required => 1 );
has 'pid_file'     => ( isa => 'Str',
			is   => 'ro',
                        default => '/var/run/smtpauth/log-collector.pid' );
has '_limitter'    => ( isa      => 'Milter::SMTPAuth::Limit',
			is       => 'rw',
		        required => 1);
has '_geoip',      => ( isa      => 'Maybe[Milter::SMTPAuth::Utils::GeoIP]',
                        is       => 'rw',
                        default  => undef );

Readonly::Scalar my $DEFAULT_THRESHOLD    => 120;
Readonly::Scalar my $DEFAULT_PERIOD       => 20;
Readonly::Scalar my $DEFAULT_MAX_MESSAGES => 10_000;

sub check_positive_number {
    my ( $number, $default ) = @_;
    if ( ! defined( $number ) || ! looks_like_number( $number ) || $number < 0 ) {
	return $default;
    }
    return $number;
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig( @_ );

    openlog( 'smtpauth-log-collector', 'ndelay,pid,nowait', 'mail' );

    my $threshold = check_positive_number( $args->{threshold}, $DEFAULT_THRESHOLD );
    my $period    = check_positive_number( $args->{period},    $DEFAULT_PERIOD );
    delete( $args->{threshold} );
    delete( $args->{period} );

    if ( ! exists( $args->{user} ) || ! exists( $args->{group} ) ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "$class::new must be specified user and group.",
	);
    }

    my $socket   = _create_socket( $args );
    delete( $args->{recv_address} );
    $args->{_recv_socket} = $socket;

    my %geoip_args;
    if ( $args->{geoip_v4} ) {
	$geoip_args{database_filename_v4} = $args->{geoip_v4};
    }
    if ( $args->{geoip_v6} ) {
	$geoip_args{database_filename_v6} = $args->{geoip_v6};
    }
    if ( $geoip_args{database_filename_v4} || $geoip_args{database_filename_v6} ) {
        $args->{_geoip} = new Milter::SMTPAuth::Utils::GeoIP( \%geoip_args );
    }
    delete $args->{geoip_v4};
    delete $args->{geoip_v6};

    my $max_messages = check_positive_number( $args->{max_messages}, $DEFAULT_MAX_MESSAGES );
    delete $args->{max_messages};

    my $limitter = new Milter::SMTPAuth::Limit(
	threshold       => $threshold,
	period          => $period,
	recv_log_socket => $socket,
	max_messages    => $max_messages,
	auto_reject     => $args->{auto_reject},
        geoip           => $args->{_geoip},
    );
    delete( $args->{auto_reject} );
    $args->{_limitter} = $limitter;

    if ( $args->{weight_file} && -f $args->{weight_file} ) {
	$limitter->load_config_file( $args->{weight_file} );
    }
    delete( $args->{weight_file} );

    if ( ! $args->{foreground} ) {
        Milter::SMTPAuth::Utils::daemonize( $args->{pid_file} );
    }
    delete( $args->{foregound} );

    set_effective_id( $args->{user}, $args->{group} );
    delete( $args->{user} );
    delete( $args->{group} );

    return $args;
};


=head1 NAME

Milter::SMTPAuth::Logger - Milter::SMTPAuth::Logger statistics log module.


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
        foregound    => 0,
        max_messages => 10000,
        weight_file  => '/etc/smtpatuh/weight.json',
        auto_reject  => 1,
        geoip_v4     => '/usr/share/GeoIP/GeoIP.dat',
        geoip_v6     => '/usr/share/GeoIP/GeoIOv6.dat',
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

=item * formatter

subclass of Milter::SMTPAuth::Logger::Formatter.

=item * recv_address

path of UNIX Domain Socket or IP Address and port for receive log message.

=item * user

EUID or username of process.

=item * group

EGID or groupname of process

=item * foreground

if foreground is true, process excute foreground mode.
if foreground is false, process execute daemon mode.

=item * weight_file

wieght_file is the JSON file, that specify the weight of message score.

=item * auto_reject

if auto_reject is true, auth id, which send too many mail, is added to access db automatically.

=item * geoip_v4

geoip option specify GeoIP Database file(IPv4).

=item * geoip_v6

geoip option specify GeoIP Database file(IPv6).

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
    my $this = shift;

    eval {
	syslog( 'info', 'started' );
      LOG_ACCEPT:
	while ( $is_continue ) {
	    $this->_limitter->wait_log();

	    my $log_text;
	    my $peer = $this->_recv_socket->recv( $log_text, 10240 );
	    if ( defined( $peer ) ) {
		if ( $log_text eq q{} ) {
		    next LOG_ACCEPT;
		}

		my $message = thaw( $log_text );
		if ( $this->_geoip && $message->client_address() ) {
		    $message->country( $this->_geoip->get_country_code( $message->client_address ) );
		}

		my $formatted_log = $this->formatter()->output( $message );
		$this->outputter->output( $formatted_log );
		$this->_rrd->output( $message );
		$this->_limitter->increment( $message );
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

    $this->_delete_pid_file();
}


sub _create_socket {
    my ( $args ) = @_;

    my $socket_params = Milter::SMTPAuth::SocketParams::parse( $args->{recv_address} );
    if ( $socket_params->is_inet() ) {
	return _create_inet_socket( $socket_params->address, $socket_params->port );
    }
    else {
	return _create_unix_socket( $socket_params->address, $args->{user}, $args->{group} );
    }
}


sub _create_inet_socket {
    my ( $address, $port ) = @_;

    my $socket = new IO::Socket::INET(
	LocalAddr => $address,
	LocalPort => $port,
	Proto     => 'udp',
	Type      => SOCK_DGRAM,
    );
    if ( ! defined( $socket ) ) {
	Milter::SMTPAuth::LoggerError->throw(
	    error_message => sprintf( 'cannot open Logger recv socket "%s:%d"(%s)', $address, $port, $ERRNO ),
	);
    }
    return $socket;
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

sub _delete_pid_file {
    my ( $this ) = @_;

    if ( -f $this->pid_file() ) {
	unlink( $this->pid_file() );
    }
}


no Moose;
__PACKAGE__->meta->make_immutable();

1;

