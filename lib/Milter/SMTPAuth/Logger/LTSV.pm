# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::LTSV;

use Readonly;
use Data::Dumper;
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::Logger::Formatter;
use Moose;
with 'Milter::SMTPAuth::Logger::Formatter';

Readonly::Scalar my $TIME_FORMAT => "%Y-%m-%d %H:%M:%S %Z";

=head1 NAME

Milter::SMTPAuth::Logger::LTSV - LTSV Format


=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Logger::LTSV;

    my $formatter = new Milter::SMTPAuth::Logger::LTSV();

    my $message = new Milter::SMTPAuth::Message();
    ...

    my $log = $formatter->output( $message );

=head1 SUBROUTINES/METHODS

=head2 new

create Formatter instance.

=head2 output

=cut

sub output {
    my $this = shift;
    my ( $message ) = @_;

    my %value_of;
    $value_of{connect_time} = print_time( $message->connect_time() )
        if $message->connect_time();
    $value_of{eom_time} = print_time( $message->eom_time() )
        if $message->eom_time();
    $value_of{client_address} = $message->client_address()
        if $message->client_address();
    $value_of{client_port} = $message->client_port()
        if $message->client_port();
    $value_of{auth_id} = $message->auth_id() if $message->auth_id();
    $value_of{sender} = $message->sender_address()
        if $message->sender_address();
    $value_of{size}     = $message->size()     if $message->size();
    $value_of{queue_id} = $message->queue_id() if $message->queue_id();
    $value_of{country}  = $message->country()  if $message->country();

    my @columns;
    while ( my ( $label, $value ) = each( %value_of ) ) {
        push( @columns, "$label:$value" );
    }

    foreach my $recipient ( $message->list_recipient_addresses() ) {
        push( @columns, "recipient:$recipient" );
    }

    return join( qq{\t}, @columns ) . qq{\n};
}

sub input {
    my ( $this ) = @_;

    my ( $input, $loaded_messages_ref ) = @_;

    while ( my $line = $input->getline ) {
        chomp( $line );
        my $message = new Milter::SMTPAuth::Message;
        foreach my $col ( split( "\t", $line ) ) {
            my ( $label, $value ) = split( ":", $col );
            if ( $label eq "connect_time" ) {
                $message->connected_time( parse_time( $value ) );
            }
            elsif ( $label eq "eom_time" ) {
                $message->eom_time( parse_time( $value ) );
            }
            elsif ( $label eq "client_address" ) {
                $message->client_address( $value );
            }
            elsif ( $label eq "client_port" ) {
                $message->client_port( $value );
            }
            elsif ( $label eq "sender" ) {
                $message->sender_address( $value );
            }
            elsif ( $label eq "auth_id" ) {
                $message->auth_id( $value );
            }
            elsif ( $label eq "queue_id" ) {
                $message->queue_id( $value );
            }
            elsif ( $label eq "size" ) {
                $message->size( $value );
            }
            elsif ( $label eq "recipient" ) {
                $message->add_recipient_address( $value );
            }
        }
        push( @{$loaded_messages_ref}, $message );
    }
}

sub parse_time {
    return Time::Piece::strptime( $_[ 0 ], $TIME_FORMAT );
}

sub print_time {
    return $_[ 0 ]->strftime( $TIME_FORMAT );
}

1;
