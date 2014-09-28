
package Milter::SMTPAuth::Limit;

use Moose;
use IO::Select;
use Sys::Syslog;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Exception;

has 'score_of'          => ( isa => 'HashRef',    is => 'rw', default  => sub { {} } );
has 'period'            => ( isa => 'Int',        is => 'ro', default  => 60 );
has 'io_select'         => ( isa => 'IO::Select', is => 'rw', required => 1 );
has 'threshold'         => ( isa => 'Int',        is => 'ro' );
has 'last_updated_time' => ( isa => 'Int',        is => 'rw', default  => sub { time() } );

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
	    error_message => $class . "::new has Hash reference argument."
	);
    }

    if ( ! $args_ref->{recv_log_socket} ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => $class . "::new has recv_log_socket option."
	);
    }

    my $select = new IO::Select( ( $args_ref->{recv_log_sockt} ) );
    delete $args_ref->{recv_log_socket};
    $args_ref->{io_select} = $select;

    return $class->$orig( $args_ref );
};


=head1 NAME

Milter::SMTPAuth::Limit - Milter::SMTPAuth::Filter statistics log module.


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



sub increment {
    my $this = shift;
    my ( $message ) = @_;

    $this->score_of->{ $message->auth_id() } += $message->recipients_count;
}

sub wait {
    my $this = shift;

    my @can_read = $this->io_select->can_read( $this->wait_time() );
    syslog( 'debug', 'can read %d', $#can_read + 1 );
    if ( $this->wait_time() < 1 ) {
	$this->count_messages();
    }
}

sub wait_time {
    my $this = shift;

    return $this->period - ( time() - $this->last_updated_time );
}


sub count_messages {
    my $this = shift;

    foreach my $auth_id ( keys( %{ $this->score_of } ) ) {
	my $score = $this->score_of->{ $auth_id };
	syslog( 'debug',
		'auth_id %s/messages %d',
		$auth_id,
		$score );

        if ( $score > $this->threshold ) {
            # action
            #
            syslog( 'info',
                    'too many message sent ( %.2f recipients / %.2f seconds ).',
                    $score,
                    $this->period );
        }
    }
    $this->score_of( {} );
    $this->last_updated_time( time() );
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
