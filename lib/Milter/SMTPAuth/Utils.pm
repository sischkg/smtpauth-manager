
package Milter::SMTPAuth::Utils;

use strict;
use warnings;
use English;
use Sys::Syslog;
use autodie;
use Fcntl;
use IO::File;
use Readonly;
use Milter::SMTPAuth::Exception;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
		    set_effective_id
		    check_args
		    change_owner
		    change_mode
		    read_from_file
		    write_to_file
		    match_ip_address
	    );

Readonly::Scalar my $IP_ADDRESS_REGEX => qr{((\d+)\.(\d+)\.(\d+)\.(\d+))};

sub match_ip_address {
    my ( $str ) = @_;

    if ( $str =~ qr{\A$IP_ADDRESS_REGEX\z} ) {
	return {
	    address => $1,
	    octet_1 => $2,
	    octet_2 => $3,
	    octet_3 => $4,
	    octet_4 => $5,
	};
    }
    elsif ( $str =~ qr{\A$IP_ADDRESS_REGEX/(\d+)\z} ) {
	return {
	    address    => $1,
	    octet_1    => $2,
	    octet_2    => $3,
	    octet_3    => $4,
	    octet_4    => $5,
	    bit_length => $6,
	};
    }
    else {
	return undef;
    }
}

sub check_args {
    my ( $args, $key_of, $default_value_of ) = @_;

    if ( ! $args || ! $key_of ) {
	Milter::SMTPAuth::ArgumentError->throw(
            message => "check_args must have 2 or 3 arguments",
	);
    }

    while ( my ( $key, $flag ) = each( %{ $key_of } ) ) {
	if ( ! exists( $args->{$key} ) ) {
	    if ( $flag eq 'req' ) {
		Milter::SMTPAuth::ArgumentError->throw(
		    message => "$key must be specified",
		);
	    }
	    elsif ( $default_value_of && exists( $default_value_of->{$key} ) ) {
		$args->{$key} = $default_value_of->{$key};
	    }
	}
    }
    while ( my ( $key, $flag ) = each( %{ $args } ) ) {
	if ( ! exists( $key_of->{$key} ) ) {
	    Milter::SMTPAuth::ArgumentError->throw(
		message => "$key is unknown",
	    );
	}
    }
    return $args;
}

sub set_effective_id {
    my ( $user, $group ) = @_;

    my $gid = getgrnam( $group );
    if ( $gid ) {
        $EGID = $gid;
    }
    else {
        syslog( 'err', 'not found group %s', $group );
    }

    my $uid = getpwnam( $user );
    if ( $uid ) {
        $EUID = $uid;
    }
    else {
        syslog( 'err', 'not found user %s', $user );
    }
}


sub change_owner {
    my ( $user, $group, $file ) = @_;

    my $gid = getgrnam( $group );
    if ( ! defined( $gid ) ) {
        Milter::SMTPAuth::ArgumentError->throw(
	    message => "$group is unknown"
	);
    }

    my $uid = getpwnam( $user );
    if ( ! defined( $uid) ) {
        Milter::SMTPAuth::ArgumentError->throw(
	    message => "$user is unknown"
	);
    }

    if ( chown( $uid, $gid, $file ) == 0 ) {
        Milter::SMTPAuth::SystemError->throw(
	    message => "cannot chown $file to $uid:$gid($ERRNO)."
	);
    }
}


sub change_mode {
    my ( $mode, $file ) = @_;

    if ( chmod( $mode, $file ) <= 0 ) {
	Milter::SMTPAuth::LoggerError->throw(
	    error_message => sprintf( 'cannot chmod file "%s"(%s)', $file, $ERRNO ),
	);
    }
}


sub daemonize {
    my ( $pid_file ) = @_;

    eval {
	if ( fork() ) {
	    exit( 0 );
	}
	if ( fork() ) {
	    exit( 0 );
	}

	close( STDIN );
	close( STDOUT );
	close( STDERR );

	chdir( q{/} );
	POSIX::setsid();

	if ( -f $pid_file ) {
	    syslog( 'err', 'pid file %s exists, already running?', $pid_file );
	    exit( 1 );
	}
	my $pid = new IO::File( $pid_file, O_WRONLY | O_CREAT | O_TRUNC );
        if ( ! defined( $pid ) ) {
            die "cannot open $pid_file file($ERRNO)."
        }
        printf $pid "%s\n", $PID;
        close( $pid );
    };
    if ( my $error = $EVAL_ERROR ) {
	syslog( 'err', 'cannot daemonize(%s).', $error );
	exit( 1 );
    }
}

sub detete_pid_file {
    my ( $pid_file ) = @_;
    if ( -f $pid_file ) {
        unlink( $pid_file );
    }
}


sub read_from_file {
    my ( $filename ) = @_;

    my $input = new IO::File( $filename );
    if ( ! $input ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot open file "$filename"($ERRNO).},
	);
    }

    my $content = do { local $/ = undef; <$input> };

    $input->close();
    return $content;
}

sub write_to_file {
    my ( $filename, $content ) = @_;

    my $tmp = sprintf( "%s.%d.%d.%d.tmp", $filename, $PID, time(), rand() );

    my $output = new IO::File( $tmp, O_WRONLY | O_CREAT | O_EXCL );
    if ( ! $output ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot open file "$filename"($ERRNO).},
	);
    }

    if ( ! $output->print( $content ) ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot write to "$tmp"($ERRNO).},
	);
    }

    if ( ! $output->close() ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot close "$tmp"($ERRNO).},
	);
    }

    if ( ! rename( $tmp, $filename ) ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot move "$tmp" to "$filename"($ERRNO).},
	);
    }
}

package Milter::SMTPAuth::SocketParams;

use Moose;
use constant UNIX => 1;
use constant INET => 2;

has 'type'    => ( isa => 'Int',        is => 'ro', required => 1 );
has 'address' => ( isa => 'Str',        is => 'ro', required => 1 );
has 'port'    => ( isa => 'Maybe[Int]', is => 'ro', default => undef );

sub is_unix {
    my ( $this ) = @_;
    return $this->type == UNIX;
}

sub is_inet {
    my ( $this ) = @_;
    return $this->type == INET;
}

sub parse_socket_address {
    my ( $address_string ) = @_;

    if ( $address_string =~ m{\Ainet:(.+):(\d+)\z}xms ||
	 $address_string =~ m{\A(\d+ \. \d+ \. \d+ \. \d+):(\d+)\z}xms ) {
	return new Milter::SMTPAuth::SocketParams(
	    type    => INET,
	    address => $1,
	    port    => $2,
	);
    }
    elsif ( $address_string =~ m{\Aunix:(.*)\z}xms ||
	    $address_string =~ m{\A(/.+)\z}xms ) {
	return new Milter::SMTPAuth::SocketParams(
	    type    => UNIX,
	    address => $1,
	);
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    message => sprintf( qq{unknown socket address "%s"}, $address_string ),
	);
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
