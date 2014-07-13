# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::LTSV;

use Data::Dumper;
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::Logger::Formatter;
use Moose;
with 'Milter::SMTPAuth::Logger::Formatter';

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
    $value_of{ connect_time } = $message->connect_time()->strftime( "%Y-%m-%d %H:%M:%S %Z" ) if $message->connect_time();
    $value_of{ eom_time }     = $message->eom_time()->strftime( "%Y-%m-%d %H:%M:%S %z" ) if $message->eom_time();
    $value_of{ client }       = $message->client_address() if $message->client_address();
    $value_of{ auth_id }      = $message->auth_id()        if $message->auth_id();
    $value_of{ sender }       = $message->sender_address() if $message->sender_address();

    my @columns;
    while ( my ( $label, $value ) = each( %value_of ) ) {
	push( @columns, "$label:$value" );
    }

    foreach my $recipient ( $message->list_recipient_addresses() ) {
	push( @columns, "recipient:$recipient" );
    }

    return join( qq{\t}, @columns ) . qq{\n};
}


1;
