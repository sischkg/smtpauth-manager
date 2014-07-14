package Milter::SMTPAuth::Filter::Imp;

use Moose;
use English;
use Readonly;
use Sys::Syslog;
use Email::Address;
use Sendmail::PMilter qw( :all );
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::AccessDB;
use Milter::SMTPAuth::AccessDB::File;
use Milter::SMTPAuth::Logger::Client;
use Milter::SMTPAuth::Utils;

use Data::Dumper;

has 'logger_address' => ( isa      => 'Str',
		          is       => 'ro',
			  required => 1 );

has 'logger' => ( isa     => 'Maybe[Milter::SMTPAuth::Logger::Client]',
		  is      => 'rw',
		  default => undef );

sub connect {
    my $this = shift;
    my ( $context ) = @_;

    my $message = new Milter::SMTPAuth::Message;
    $message->connect_time( time() );

    $message->client_address( $context->getsymval( "{client_addr}" ) );
    $message->client_port( $context->getsymval( "{client_port}"  ) );

    # If '{client_addr}' macro does not exist(default does not exit),
    # client IP address can be got from "_" macro.
    if ( ! $message->client_address ) {
	my $client = $context->getsymval( q{_} );
	if ( $client =~ /\[(\S+)\]/ ) {
	    # matched remote.host.addr[xxx.xxx.xxx.xxx]
	    $message->client_address( $1 );
	}
    }

    $context->setpriv( $message );
    return SMFIS_CONTINUE;
}


sub envfrom {
    my $this = shift;
    my ( $context, $sender ) = @_;
    my $auth_id;

    my $message = $context->getpriv();
    $message->sender_address( _parse_address( $sender ) );

    $auth_id = $context->getsymval( '{auth_authen}' );
    if ( ! defined( $auth_id ) ) {
	return SMFIS_CONTINUE;
    }

    my $access_db = new Milter::SMTPAuth::AccessDB;
    my $file_db   = new Milter::SMTPAuth::AccessDB::File;
    $access_db->add_database( $file_db );
    if ( $access_db->is_reject( $auth_id ) ) {
	$context->setreply( 550, '5.7.1', 'Access denied' );
	syslog( 'info', 'reject message from auth_id: %s', $auth_id );
	return SMFIS_REJECT;
    }
    syslog( 'info', 'accept message from auth_id: %s', $auth_id );
    $message->auth_id( $auth_id );

    return SMFIS_CONTINUE;
}

sub envrcpt {
    my $this = shift;
    my ( $context, $recipient_address ) = @_;

    my $message = $context->getpriv();
    $message->add_recipient_address( _parse_address( $recipient_address ) );

    return SMFIS_CONTINUE;
}

sub eom {
    my $this = shift;
    my ( $context ) = @_;

    my $queue_id = $context->getsymval( 'i' );
    my $size     = $context->getsymval( '{msg_size}' );
    my $message = $context->getpriv();
    if ( defined( $queue_id ) ) {
	$message->queue_id( $queue_id );
    }
    if ( defined( $size ) ) {
	$message->size( $size );
    }
    $message->eom_time( time() );

    if ( ! defined( $this->logger ) ) {
	$this->logger( new Milter::SMTPAuth::Logger::Client( logger_address => $this->logger_address() ) );
    }
    $this->logger()->send( $message );
    return SMFIS_CONTINUE;
}

sub abort {
    my $this = shift;
    my ( $context ) = @_;

    my $message = $context->getpriv();
    $message->clear();

    return SMFIS_CONTINUE;
}

sub close {
    my $this = shift;
    my ( $context ) = @_;

    $context->setpriv( undef );

    return SMFIS_CONTINUE;
}

sub _parse_address {
    my ( $str ) = @_;

    my @addresses = Email::Address->parse( $str );
    if ( @addresses ) {
        return $addresses[0]->address;
    }
    return $str;
}

no Moose;
__PACKAGE__->meta->make_immutable();

package Milter::SMTPAuth::Filter;

use Moose;
use English;
use Sys::Syslog;
use Sendmail::PMilter qw( :all );
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Exception;
use Data::Dumper;

extends qw( Moose::Object Sendmail::PMilter );

has 'imp' => ( isa => 'Milter::SMTPAuth::Filter::Imp',
	       is  => 'rw',
	       required => 1 );
has 'listen_address' => ( isa => 'Str',  is  => 'ro', required => 1 );
has 'user'           => ( isa => 'Str',  is  => 'ro', required => 1 );
has 'group'          => ( isa => 'Str',  is  => 'ro', required => 1 );
has 'foreground'     => ( isa => 'Bool', is  => 'ro', default  => 0 );
has 'pid_file'       => ( isa => 'Str',  is  => 'ro', default  => '/var/run/smtpauth/filter.pid' );
has 'max_children'   => ( isa => 'Int',  is  => 'ro', required => 1 );
has 'max_requests'   => ( isa => 'Int',  is  => 'ro', required => 1 );


=head1 NAME

Milter::SMTPAuth::Filter

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Filter;

    my $filter = new Milter::SMTPAuth::Filter( listen_address => '/var/run/smtpauth/filter.sock',
	                                       logger_address => '/var/run/smtpauth/logger.sock',
	                                       user           => 'smtpauth-manager',
                                               group          => 'smtpauth-manager',
                                               foreground     => 0,
                                               max_children   => 30,
                                               max_requests   => 1000 );
    $filter->run();


=head1 SUBROUTINES/METHODS

=head2 new

create instance of Milter::SMTPAuth::Milter.

=over 4

=item * listen_address

UNIX domain socket path of milter service.

=item * logger_address

UNIX domain socket path to output statistics logs.

=item * user

Effective User of process.

=item * group

Effective Group of process.

=item * max_children

Max number of child processes. See Sendmail::PMilter document.

=item * max_requests

Max number of requests per one process. See Sendmail::PMilter document.

=cut


Readonly::Hash my %CALLBACK_METHOD_OF => {
    connect => \&_callback_connect,
    envfrom => \&_callback_envfrom,
    envrcpt => \&_callback_envrcpt,
    eom     => \&_callback_eom,
    abort   => \&_callback_abort,
    close   => \&_callback_close,
};


=head2 run()

start milter service.

=cut


around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my @args  = @_;

    my $args_ref;
    if ( @args == 1 && ref $args[0] ) {
	# contstructor args is Hash reference.
	$args_ref = $args[0];
    }
    elsif ( @args % 2 == 0 ) {
	my %args = @args;
	$args_ref = \%args;
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "Milter::SMTPAuth::Filter::new has Hash reference argument."
	);
    }

    if ( ! $args_ref->{logger_address} ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "Milter::SMTPAuth::Filter::new has logger_address option."
	);
    }
    $args_ref->{imp} = new Milter::SMTPAuth::Filter::Imp( logger_address => $args_ref->{logger_address} );
    delete $args_ref->{logger_address};

    if ( ! $args_ref->{listen_address} ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => "Milter::SMTPAuth::Filter::new has listen_address option."
	);
    }

    return $class->$orig( $args_ref );
};


sub run {
    my $this = shift;

    openlog( 'smtpauth-filter',
	     'ndelay,pid,nowait',
	     'mail' );

    my $filter_socket_param = Milter::SMTPAuth::SocketParams::parse_socket_address( $this->listen_address );
    my $listen_address;
    if ( $filter_socket_param->is_unix() ) {
	$listen_address = sprintf( 'local:%s', $filter_socket_param->address() );
    }
    else {
	$listen_address = sprintf( 'inet:%d@%s', $filter_socket_param->port(), $filter_socket_param->address() );
    }

    eval {
        if ( ! $this->foreground() ) {
            Milter::SMTPAuth::Utils::daemonize( $this->pid_file );
        }

	if ( $filter_socket_param->is_unix() && -e $filter_socket_param->address() ) {
            unlink( $filter_socket_param->address() );
        }

        set_effective_id( $this->user(), $this->group() );
        $this->setconn( $listen_address );
        $this->_register_callbacks();
        $this->set_dispatcher( Sendmail::PMilter::prefork_dispatcher );

	if ( $filter_socket_param->is_unix() ) {
	    chmod( 0660, $filter_socket_param->address() );
	}
    };
    if ( my $error = $EVAL_ERROR ) {
        syslog( 'err', 'cannot start(%s).', $error );
        exit( 1 );
    }

    syslog( 'info', 'started' );
    $this->main( $this->max_children(), $this->max_requests() );
}


sub _register_callbacks {
    my $this = shift;

    my %callback_of;
    while ( my ( $name, $method ) = each( %CALLBACK_METHOD_OF ) ) {
	$callback_of{ $name } = sub {
	    my @args = @_;
	    &$method( $this, @args );
	}
    }
    $this->register( 'smtpauth-filter', \%callback_of, SMFI_CURR_ACTS );
}


sub _callback {
    my $this = shift;
    my ( $name, $context, @args ) = @_;

    my $response_code = eval {
	return $this->imp->$name( $context, @args );
    };
    if ( my $error = $EVAL_ERROR ) {
        syslog( 'err', 'caught error at _callback_%s(%s).', $name, $error );
        $response_code = SMFIS_CONTINUE;
    }

    syslog( 'debug', 'return %s at _callback_%s', $response_code, $name );
    return $response_code;
}


sub _callback_connect {
    my $this = shift;
    my ( $context, $remote_host ) = @_;

    return $this->_callback( 'connect', $context, $remote_host );
}

sub _callback_envfrom {
    my $this = shift;
    my ( $context, $sender ) = @_;

    return $this->_callback( 'envfrom', $context, $sender );
}

sub _callback_envrcpt {
    my $this = shift;
    my ( $context, $recipient ) = @_;

    return $this->_callback( 'envrcpt', $context, $recipient );
}

sub _callback_eom {
    my $this = shift;
    my ( $context ) = @_;

    return $this->_callback( 'eom', $context );
}

sub _callback_abort {
    my $this = shift;
    my ( $context ) = @_;

    return $this->_callback( 'abort', $context );
};

sub _callback_close {
    my $this = shift;
    my ( $context ) = @_;

    return $this->_callback( 'abort', $context );
};


no Moose;
__PACKAGE__->meta->make_immutable();

1;

