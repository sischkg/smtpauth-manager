
package Milter::SMTPAuth::Limit;

use Moose;
use IO::Select;
use Sys::Syslog;
use JSON::PP;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Limit::NetworkWeight;
use Milter::SMTPAuth::Limit::AuthIDWeight;

has 'messages_of'       => ( isa => 'HashRef',    is => 'rw', default  => sub { {} } );
has 'period'            => ( isa => 'Int',        is => 'ro', default  => 60 );
has 'io_select'         => ( isa => 'IO::Select', is => 'rw', required => 1 );
has 'threshold'         => ( isa => 'Int',        is => 'ro' );
has 'last_updated_time' => ( isa => 'Int',        is => 'rw', default  => sub { time() } );
has 'weight_filters'    => ( isa => 'ArrayRef[Object]',
			     is  => 'rw',
			     default => sub { [
				 new Milter::SMTPAuth::Limit::AuthIDWeight,
				 new Milter::SMTPAuth::Limit::NetworkWeight,
			     ] } );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my @args  = @_;

    my $args_ref;
    if ( @args == 1 && ref $args[0] ) {
	# contstructor args is Hash reference.
	$args_ref = $args[0];
    } elsif ( @args % 2 == 0 ) {
	my %args = @args;
	$args_ref = \%args;
    } else {
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

Milter::SMTPAuth::Limit

=head1 SYNOPSIS

Quick summary of what the module does.

    # vi /etc/smtpauth/weight.json

    {
      "network": [
        {
           "network": "192.168.0.0/16",
           "weight":  0.1
        },
        {
           "network": "10.0.0.0/8",
           "weight":  0.1
        },
        {
           "network": "1.0.0.0/8",
           "weight":  3
        }
      ],
      "auth_id": [
        {
          "auth_id": "root",
          "weight": 0
        },
        {
          "auth_id": "spam",
          "weight": 10
        }
      ]
    }


    # log server
    use Milter::SMTPAuth::Logger;

    my $recv_log_socket = new IO::Socket::INET( .... );

    # If one auth_id sent messages more than 200msg per 60 seconds,
    # Milter::SMTPAuth::Limit send alert log.
    my $limit = new Milter::SMTPAuth::Limit(
        recv_log_socket => $recv_log_socket,
        period          => 60,
        threshold       => 200,
    );
    $limit->load_config_file( '/etc/smtpauth/weight.json' );

    while ( 1 ) {
       $limit->wait_log();

       my $log;
       $recv_log_socket->recv( $log, 10000 );
       ...
       my $message = new Milter::SMTPAuth::Message;
       ...
       $limit->increment( $message );
       ...
    }

=head1 SUBROUTINES/METHODS

=head2 new

create Limit Instance.

=over 4

=item * period

The period(second) of calculating score.

=item * threshold

Alert threshold of score.

=item * recv_log_socket

UNIX Domain or INET Socket for receive log message.

=back

=head2 load_config_file( $filename )

Load limit config from JSON file.

=cut

sub load_config_file {
    my $this = shift;
    my ( $filename ) = @_;

    my $config_file = read_from_file( $filename );
    $this->load_config( $config_file );
}

=head2 load_config( $data )

Load limit config from JSON string.

=cut

sub load_config {
    my $this = shift;
    my ( $config_file ) = @_;
    my $config_data = decode_json( $config_file );

    foreach my $filter ( @{ $this->weight_filters() } ) {
	$filter->load_config( $config_data );
    }
}

=head2 increment( $message )

Add message infomation for calculating score.

=cut

sub increment {
    my $this = shift;
    my ( $message ) = @_;

    if ( ! exists( $this->messages_of->{ $message->auth_id() } ) ) {
	$this->messages_of->{ $message->auth_id() } = [];
    }
    push( @{ $this->messages_of->{ $message->auth_id() } }, $message );
}

=head2 wait_log()

Wait until log data can be recieved or calculate period time is passed.

=cut

sub wait_log {
    my $this = shift;

    my @can_read = $this->io_select->can_read( $this->_wait_time() );
#    syslog( 'debug', 'can read descriter %d', $#can_read + 1 );
    if ( $this->_wait_time() < 1 ) {
	$this->_calculate_score();
    }
}

sub _wait_time {
    my $this = shift;

    return $this->period - ( time() - $this->last_updated_time() );
}


sub _calculate_score {
    my $this = shift;

    foreach my $auth_id ( keys( %{ $this->messages_of } ) ) {
	my $total_score = 0;
	foreach my $message ( @{ $this->messages_of->{ $auth_id } } ) {
	    my $score = $message->recipients_count();
	    foreach my $filter ( @{ $this->weight_filters() } ) {
		$score *= $filter->get_weight( $message );
	    }
	    $total_score += $score;
	}

	syslog( 'debug', 'auth_id %s/score %f', $auth_id, $total_score );

        if ( $total_score > $this->threshold() ) {
            # action
            #
            syslog( 'info',
                    'too many message sent by %s( %.2f points / %.2f seconds ).',
		    $auth_id,
                    $total_score,
                    $this->period() );
        }
    }
    $this->messages_of( {} );
    $this->last_updated_time( time() );
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
