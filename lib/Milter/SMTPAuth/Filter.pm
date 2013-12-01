package Milter::SMTPAuth::Filter;

use Moose;
use English;
use Readonly;
use Sys::Syslog;
use Email::Address;
use Sendmail::PMilter qw( :all );
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::AccessDB;
use Milter::SMTPAuth::Logger::Client;
use Milter::SMTPAuth::Utils;
use Data::Dumper;

extends qw( Moose::Object Sendmail::PMilter );

has 'listen_path' => ( isa => 'Str',
					   is  => 'ro',
					   required => 1 );
has 'logger_path' => ( isa => 'Str',
					   is  => 'ro',
					   required => 1 );
has 'user' => ( isa => 'Str',
				is  => 'ro',
				required => 1 );
has 'group' => ( isa => 'Str',
				 is  => 'ro',
				 required => 1 );
has 'max_children' => ( isa => 'Int',
						is  => 'ro',
						required => 1 );
has 'max_requests' => ( isa => 'Int',
						is  => 'ro',
						required => 1 );

=head1 NAME

Milter::SMTPAuth::Filter

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Filter;

    my $filter = new Milter::SMTPAuth::Filter( listen_path  => '/var/run/smtpauth/filter.sock',
	                                           logger_path  => '/var/run/smtpauth/logger.sock',
	                                           user         => 'smtpauth-manager',
                                               group        => 'smtpauth-manager',
                                               max_children => 30,
                                               max_requests => 1000 );
    $filter->run();


=head1 SUBROUTINES/METHODS

=head2 new

create instance of Milter::SMTPAuth::Milter.

=over 4

=item * listen_path

UNIX domain socket path of milter service.
 
=item * logger_path

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


sub run {
    my $this = shift;

    openlog( 'smtpauth-filter',
	     'ndelay,pid,nowait',
	     'mail' );

    my $milter_listen_path = sprintf( 'local:%s', $this->listen_path() ); 
    eval {
        if ( -e $this->listen_path() ) {
            unlink( $this->listen_path() );
        }

        set_effective_id( $this->user(), $this->group() );
        $this->setconn( $milter_listen_path );
        $this->_register_callbacks();
        $this->set_dispatcher( Sendmail::PMilter::prefork_dispatcher );

        chmod( 0660, $this->listen_path() );
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

sub _callback_connect {
	my $this = shift;
	my ( $context ) = @_;

	print Dumper( $this, $context );

	my $message = new Milter::SMTPAuth::Message;
	$message->connect_time( time() );

	my $client = $context->getsymval( q{_} );
	if ( $client =~ /\[(\S+)\]/ ) {
		# matched remote.host.addr[xxx.xxx.xxx.xxx]
		$message->client_address( $1 );
	}

	$context->setpriv( $message );

	return SMFIS_CONTINUE;
}


sub _callback_envfrom {
	my $this = shift;
	my ( $context, $sender ) = @_;
	my $auth_id;

    my $return_code = eval {
        my $message = $context->getpriv();
        $message->sender_address( _parse_address( $sender ) );

        $auth_id = $context->getsymval( '{auth_authen}' );
        if ( ! defined( $auth_id ) ) {
            return SMFIS_CONTINUE;
        }

        my $access_db = new Milter::SMTPAuth::AccessDB;
        if ( $access_db->is_reject( $auth_id ) ) {
            $context->setreply( 550, '5.7.1', 'Access denied' );
            syslog( 'info', 'reject message from auth_id: %s', $auth_id );
            return SMFIS_REJECT;
        }
        syslog( 'info', 'accept message from auth_id: %s', $auth_id );
        $message->auth_id( $auth_id );

        return SMFIS_CONTINUE;
    };
    if ( my $error = $EVAL_ERROR ) {
        syslog( 'err', 'caught error at _callback_envfrom(%s).', $error );
        $return_code = SMFIS_CONTINUE;
    }

	return $return_code;
}


sub _callback_envrcpt {
	my $this = shift;
	my ( $context, $recipient_address ) = @_;

    eval {
        my $message = $context->getpriv();
        $message->add_recipient_address( _parse_address( $recipient_address ) );

        return SMFIS_CONTINUE;
    };
    if ( my $error = $EVAL_ERROR ) {
        syslog( 'err', 'caught error at _callback_envrcpt(%s).', $error );
    }
	return SMFIS_CONTINUE;
}

sub _callback_eom {
	my $this = shift;
	my ( $context ) = @_;

	my $queue_id = $context->getsymval( 'i' );
	if ( ! defined( $queue_id ) ) {
		return SMFIS_CONTINUE;
	}

	my $message = $context->getpriv();
	$message->queue_id( $queue_id );
	$message->eom_time( time() );

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_path => $this->logger_path(),
    );
    $logger->send( $message );

	return SMFIS_CONTINUE;
}

sub _callback_abort {
	my $this = shift;
	my ( $context, $recipient_address ) = @_;

	my $message = $context->getpriv();
	$message->clear();

	return SMFIS_CONTINUE;
}

sub _callback_close {
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

1;

