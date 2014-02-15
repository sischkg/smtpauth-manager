
package Milter::SMTPAuth::Utils;

use strict;
use warnings;
use English;
use Sys::Syslog;
use autodie;
use Fcntl;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(set_effective_id);

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

1;

