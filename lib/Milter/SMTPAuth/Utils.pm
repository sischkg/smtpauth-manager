
package Milter::SMTPAuth::Utils;

use strict;
use warnings;
use English;
use Sys::Syslog;
use autodie;
use Fcntl;
use Milter::SMTPAuth::Exception;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(set_effective_id check_args change_owner change_mode );

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

sub parse_logger_address {
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
