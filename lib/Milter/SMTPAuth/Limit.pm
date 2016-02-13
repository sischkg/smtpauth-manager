
package Milter::SMTPAuth::Limit;

use Moose;
use IO::Select;
use Sys::Syslog;
use JSON::PP;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Limit::NetworkWeight;
use Milter::SMTPAuth::Limit::AuthIDWeight;
use Milter::SMTPAuth::Limit::GeoIPWeight;
use Milter::SMTPAuth::Limit::CountryCountWeight;
use Milter::SMTPAuth::Limit::Role;
use Milter::SMTPAuth::Action;

has 'messages_of' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );
has 'period' => ( isa => 'Int', is => 'ro', default => 60 );
has 'io_select' => ( isa => 'IO::Select', is => 'rw', required => 1 );
has 'threshold' => ( isa => 'Int', is => 'ro' );
has 'last_updated_time' => ( isa => 'Int', is => 'rw', default => sub { time() } );
has 'max_messages'      => ( isa => 'Int', is => 'ro', default => 10_000 );
has 'message_count'     => ( isa => 'Int', is => 'rw', default => 0 );
has 'weight_filters'    => (
    isa      => 'ArrayRef[Milter::SMTPAuth::Limit::Role]',
    is       => 'rw',
    required => 1 );
has 'weight_filters_of_all' => (
    isa      => 'ArrayRef[Milter::SMTPAuth::Limit::Role]',
    is       => 'rw',
    required => 1 );
has 'action' => (
    isa      => 'Milter::SMTPAuth::Action',
    is       => 'rw',
    required => 1 );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig( @_ );

    if ( !$args->{recv_log_socket} ) {
        Milter::SMTPAuth::ArgumentError->throw( error_message => $class . "::new has recv_log_socket option." );
    }

    my $select = new IO::Select( ( $args->{recv_log_socket} ) );
    delete $args->{recv_log_socket};
    $args->{io_select} = $select;

    $args->{action} = new Milter::SMTPAuth::Action(
        auto_reject      => $args->{auto_reject},
        alert_email      => $args->{alert_email},
        alert_mailhost   => $args->{alert_mailhost},
        alert_port       => $args->{alert_port},
        alert_sender     => $args->{alert_sender},
        alert_recipients => $args->{alert_recipients}, );
    delete $args->{auto_reject};
    delete $args->{alert_email};
    delete $args->{alert_mailhost};
    delete $args->{alert_port};
    delete $args->{alert_sender};
    delete $args->{alert_recipients};

    $args->{weight_filters} = [
        new Milter::SMTPAuth::Limit::AuthIDWeight,
        new Milter::SMTPAuth::Limit::NetworkWeight,
        new Milter::SMTPAuth::Limit::GeoIPWeight, ];

    $args->{weight_filters_of_all} = [ new Milter::SMTPAuth::Limit::CountryCountWeight, ];

    return $class->$orig( $args );
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
      "country": [
        {
          "code": "JP",
          "weight": 1,
        },
        {
          "code": "US",
          "weight": 2,
        },
        {
          "code": "CN",
          "weight": 5,
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
        max_messages    => 200000,
        auto_reject     => 1,
        alert_email     => 1,
        alert_mailhost  => 'mailhost.example.com',
        alert_port      => 587,
        alert_sender    => 'postmaster@example.com',
        alert_recpients => [ 'admin@example.com', ],
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

=item * max_messages

Maximum number of messages for calculating score.

=item * auto_reject

if auto_reject is true, auth_id that send many mails is added to access db file.

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
    my $this            = shift;
    my ( $config_file ) = @_;
    my $config_data     = decode_json( $config_file );

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

    if ( $this->message_count() >= $this->max_messages() ) {
        return;
    }

    $this->message_count( $this->message_count() + 1 );
    if ( !exists( $this->messages_of->{ $message->auth_id() } ) ) {
        $this->messages_of->{ $message->auth_id() } = [];
    }
    push( @{ $this->messages_of->{ $message->auth_id() } }, $message );
}

=head2 wait_log()

Wait until log data can be received or calculate period time is passed.

=cut

sub wait_log {
    my $this = shift;

    while ( 1 ) {
        syslog( 'debug', 'wait %d', $this->_wait_time() );
        my @can_read = $this->io_select->can_read( $this->_wait_time() );
        syslog( 'debug', 'can read descriter %d', $#can_read + 1 );
        if ( @can_read > 0 ) {
            last;
        }
        syslog( 'debug', 'wait %d', $this->_wait_time() );
        if ( $this->_wait_time() < 1 ) {
            syslog( 'info', 'start calculating' );
            $this->_calculate_score();
        }
    }
}

sub _wait_time {
    my $this = shift;

    return $this->period - ( time() - $this->last_updated_time() );
}

sub _calculate_score {
    my $this = shift;

    $this->action()->pre_actions();

    foreach my $auth_id ( keys( %{ $this->messages_of } ) ) {
        if ( !defined( $auth_id ) || $auth_id eq q{} ) {
            next;
        }

        my $total_score = 0;
        foreach my $message ( @{ $this->messages_of->{$auth_id} } ) {
            my $score = $message->recipients_count();
            foreach my $filter ( @{ $this->weight_filters() } ) {
                $score *= $filter->get_weight( $message );
            }
            $total_score += $score;
        }
        foreach my $filter ( @{ $this->weight_filters_of_all } ) {
            $total_score *= $filter->get_weight( $this->messages_of->{$auth_id} );
        }

        syslog( 'debug', q{auth_id "%s"/score "%f"}, $auth_id, $total_score );

        if ( $total_score > $this->threshold() ) {
            $this->action()->execute(
                {   auth_id   => $auth_id,
                    score     => $total_score,
                    threshold => $this->threshold(),
                    period    => $this->period()
                } );
        }
    }

    $this->action()->pre_actions();

    $this->message_count( 0 );
    $this->messages_of( {} );
    $this->last_updated_time( time() );
}
no Moose;
__PACKAGE__->meta->make_immutable;

1;
