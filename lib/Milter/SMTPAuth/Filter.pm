package Milter::SMTPAuth::Filter;

use strict;
use warnings;
use English;
use Readonly;
use Sys::Syslog;
use Sendmail::PMilter qw( :all );
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::AccessDB;
use Milter::SMTPAuth::Logger::Client;
use Milter::SMTPAuth::Utils;

=head1 NAME

Milter::SMTPAuth::Filter

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Filter;

    Milter::SMTPAuth::Filter::start( { listen_path  => '/var/run/smtpauth/filter.sock',
                                       logger_path  => '/var/run/smtpauth/logger.sock',
                                       max_children => 30,
                                       max_requests => 1000 } );

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

Readonly::Hash my %CALLBACK_OF => {
    connect => \&_callback_connect,
    envfrom => \&_callback_envfrom,
    envrcpt => \&_callback_envrcpt,
    eom     => \&_callback_eom,
    abort   => \&_callback_abort,
    close   => \&_callback_close,
};


my $logger_path;

sub start {
    my ( $args_ref ) = @_;

    openlog( 'smtpauth-filter',
	     'ndelay,pid,nowait',
	     'mail' );

    $logger_path     = $args_ref->{logger_path};
    my $max_children = $args_ref->{max_children};
    my $max_request  = $args_ref->{max_request};

    my $milter = new Sendmail::PMilter;
    my $listen_path = sprintf( 'local:%s', $args_ref->{listen_path} ); 
    eval {
        if ( -e $args_ref->{listen_path} ) {
            unlink( $args_ref->{listen_path} );
        }

        set_effective_id( $args_ref->{user}, $args_ref->{group} );

        $milter->setconn( $listen_path );
        
        $milter->register( 'smtpauth-filter', \%CALLBACK_OF, SMFI_CURR_ACTS);
        $milter->set_dispatcher( Sendmail::PMilter::prefork_dispatcher );

        chmod( 0660, $args_ref->{listen_path} );
    };
    if ( my $error => $EVAL_ERROR ) {
        syslog( 'err', 'cannot start(%s).', $error );
        exit( 1 );
    }
    
    syslog( 'info', 'started' );
    $milter->main( $max_children, $max_request );
}


sub _callback_connect {
	my ( $context ) = @_;

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
	my ( $context, $sender ) = @_;
	my $auth_id;

    my $return_code = eval {
        my $message = $context->getpriv();
        $message->sender_address( $sender );

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
	my ( $context, $recipient_address ) = @_;

        eval {
	my $message = $context->getpriv();
	$message->add_recipient_address( $recipient_address );

	return SMFIS_CONTINUE;
        };
        if ( my $error = $EVAL_ERROR ) {
            syslog( 'err', 'caught error at _callback_envrcpt(%s).', $error );
        }
	return SMFIS_CONTINUE;
}

sub _callback_eom {
	my ( $context ) = @_;

	my $queue_id = $context->getsymval( 'i' );
	if ( ! defined( $queue_id ) ) {
		return SMFIS_CONTINUE;
	}

	my $message = $context->getpriv();
	$message->queue_id( $queue_id );
	$message->eom_time( time() );

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_path => $logger_path,
    );
    $logger->send( $message );

	return SMFIS_CONTINUE;
}

sub _callback_abort {
	my ( $context, $recipient_address ) = @_;

	my $message = $context->getpriv();
	$message->clear();

	return SMFIS_CONTINUE;
}

sub _callback_close {
	my ( $context ) = @_;

	$context->setpriv( undef );

	return SMFIS_CONTINUE;
}

1;

