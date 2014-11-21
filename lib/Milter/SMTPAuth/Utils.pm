
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
	    );

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


package Milter::SMTPAuth::Utils::Lock;

use Moose;
use English;
use IO::File;
use Fcntl qw(:flock);
use Exception::Class;

has _lock_file => ( isa => 'Maybe[IO::File]', is => 'rw', required => 1 );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args          = $class->$orig( @_ );
    my $lock_filename = $args->{filename};
    my $lock_type     = $args->{lock_type};

    my $lock_file = new IO::File( $lock_filename, O_WRONLY | O_CREAT );
    if ( ! defined( $lock_file ) ) {
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot open lock file "$lock_filename"($ERRNO).},
	);
    }

    if ( ! defined( $lock_type ) ) {
	$lock_type = LOCK_EX;
    }

    if ( ! flock( $lock_file, $lock_type ) ) {
	$lock_file->close();
	Milter::SMTPAuth::IOError->throw(
	    error_message => qq{cannot lock file "$lock_filename"($ERRNO).},
	);
    }

    return { _lock_file => $lock_file };
};


sub DEMOLISH {
    my $this = shift;

    $this->unlock();
    if ( $this->_lock_file ) {
	$this->_lock_file->close();
    }
}



=head1 NAME

Milter::SMTPAuth::Utils::Lock

=head1 SYNOPSIS

Quick summary of what the module does.

    use Fcntl qw(:flock);
    use Milter::SMTPAuth::Utils;

    my $lock = new Milter::SMTPAuth::Utils::Lock(
        filename  => "/tmp/lock,
        lock_type => LOCK_EX,
    );

    ...

    $lock->unlock();

    or

    use Fcntl qw(:flock);
    use Milter::SMTPAuth::Utils;

    Milter::SMTPAuth::Utils::Lock::lock { .... } filename => '/tmp/lock', lock_type => LOCK_EX;


=head1 SUBROUTINES/METHODS

=head2 new

create instance of Milter::SMTPAuth::Utils::Lock, and lock file $filename.

=over 4

=item * filename

lock filename

=item * lock_type

lock_type is one of LOCK_SH, LOCK_EX.

=break

=head2 unlock

unlock file.

=cut

sub unlock {
    my $this = shift;

    if ( $this->_lock_file ) {
	$this->_lock_file->close();
	$this->_lock_file( undef );
    }
}


=head2 lock $block filename => $filename, lock_type => $lock_type;

First lock $filename. Next execute $block, last unlock $filename.

=over 4

=item * $block

=item * filename

lock filename

=item * lock_type

lock_type is one of LOCK_SH, LOCK_EX.

=break

=cut

sub lock( &@ ) {
    my ( $func, @args ) = @_;

    my %args = @args;
    my $lock_fd = new Milter::SMTPAuth::Utils::Lock(
	filename  => $args{filename},
	lock_type => $args{lock_type} || LOCK_EX,
    );

    eval {
	$func->();
    };
    if ( my $error = Exception::Class->caught() ) {
	$lock_fd->unlock();
	$error->rethrow;
    }
    elsif ( my $e = $EVAL_ERROR ) {
	$lock_fd->unlock();
	die $e;
    }
    $lock_fd->unlock();
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
