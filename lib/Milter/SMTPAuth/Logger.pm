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

has 'outputter' => (
    does     => 'Milter::SMTPAuth::Logger::Outputter',
    is       => 'rw',
    required => 1 );
has 'formatter' => (
    does     => 'Milter::SMTPAuth::Logger::Formatter',
    is       => 'rw',
    required => 1 );
has '_rrd' => (
    isa     => 'Milter::SMTPAuth::Logger::RRDTool',
    is      => 'rw',
    default => sub { new Milter::SMTPAuth::Logger::RRDTool } );
has '_recv_socket' => ( isa => 'IO::Socket', is => 'rw', required => 1 );
has 'pid_file' => (
    isa     => 'Str',
    is      => 'ro',
    default => '/var/run/smtpauth/log-collector.pid' );
has '_limitter' => (
    isa      => 'Milter::SMTPAuth::Limit',
    is       => 'rw',
    required => 1 );
has '_geoip',
    => (
    isa     => 'Maybe[Milter::SMTPAuth::Utils::GeoIP]',
    is      => 'rw',
    default => undef );

Readonly::Scalar my $DEFAULT_THRESHOLD    => 120;
Readonly::Scalar my $DEFAULT_PERIOD       => 20;
Readonly::Scalar my $DEFAULT_MAX_MESSAGES => 10_000;

sub check_positive_number {
    my ( $number, $default ) = @_;
    if ( !defined( $number ) || !looks_like_number( $number ) || $number < 0 ) {
        return $default;
    }
    return $number;
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig( @_ );

    openlog( 'smtpauth-log-collector', 'ndelay,pid,nowait', 'mail' );

    my $config = $args->{config};
    delete $args->{config};

    my $threshold = check_positive_number( $config->threshold(), $DEFAULT_THRESHOLD );
    my $period    = check_positive_number( $config->period(),    $DEFAULT_PERIOD );

    if ( !$config->user() || !$config->group() ) {
        Milter::SMTPAuth::ArgumentError->throw( error_message => "$class::new must be specified user and group.", );
    }

    my $socket = _create_socket( $config );
    $args->{_recv_socket} = $socket;

    my %geoip_args;
    if ( $config->geoip_v4 ) {
        $geoip_args{database_filename_v4} = $config->geoip_v4();
    }
    if ( $args->{geoip_v6} ) {
        $geoip_args{database_filename_v6} = $config->geoio_v6();
    }
    if (   $geoip_args{database_filename_v4}
        || $geoip_args{database_filename_v6} ) {
        $args->{_geoip} = new Milter::SMTPAuth::Utils::GeoIP( \%geoip_args );
    }

    my $max_messages = check_positive_number( $config->max_messages(), $DEFAULT_MAX_MESSAGES );

    my $limitter = new Milter::SMTPAuth::Limit(
        threshold        => $threshold,
        period           => $period,
        recv_log_socket  => $socket,
        max_messages     => $max_messages,
        auto_reject      => $config->auto_reject(),
        alert_email      => $config->alert_email(),
        alert_mailhost   => $config->alert_mailhost(),
        alert_port       => $config->alert_port(),
        alert_sender     => $config->alert_sender(),
        alert_recipients => $config->alert_recipient(),
        geoip            => $args->{_geoip} );
    $args->{_limitter} = $limitter;

    if ( $config->weight() && -f $config->weight() ) {
        $limitter->load_config_file( $config->weight() );
    }

    if ( !$config->foreground() ) {
        Milter::SMTPAuth::Utils::daemonize( $config->pid_file() );
    }

    set_effective_id( $config->user(), $config->group() );

    return $args;
};

=head1 NAME

Milter::SMTPAuth::Logger - Milter::SMTPAuth::Logger statistics log module.


=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth::Logger;
    use Milter::SMTPAuth::Logger::File;
    use Milter::SMTPAuth::Config;

    my $options = Milter::SMTPAuth::Config::LogCollectorConfig->new_with_options();

    my $logger = new Milter::SMTPAuth::Logger(
        outputter    => new Milter::SMTPAuth::Logger::File(
            logfile_name => '/var/log/smtpauth.maillog'
        ),
        formatter    => new Milter::SMTPAuth::Looger::LTSV(),
        config       => $config,
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
    my ( $config ) = @_;

    my $socket_params = Milter::SMTPAuth::SocketParams::parse( $config->recv_address );
    if ( $socket_params->is_inet() ) {
        return _create_inet_socket( $socket_params->address, $socket_params->port );
    }
    else {
        return _create_unix_socket( $socket_params->address, $config->user(), $config->group() );
    }
}

sub _create_inet_socket {
    my ( $address, $port ) = @_;

    my $socket = new IO::Socket::INET(
        LocalAddr => $address,
        LocalPort => $port,
        Proto     => 'udp',
        Type      => SOCK_DGRAM, );
    if ( !defined( $socket ) ) {
        Milter::SMTPAuth::LoggerError->throw(
            error_message => sprintf( 'cannot open Logger recv socket "%s:%d"(%s)', $address, $port, $ERRNO ), );
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
        Listen => 1, );
    if ( !defined( $socket ) ) {
        Milter::SMTPAuth::LoggerError->throw(
            error_message => sprintf( 'cannot open Logger recv socket "%s"(%s)', $path, $ERRNO ), );
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

