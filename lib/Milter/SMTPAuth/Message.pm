package Milter::SMTPAuth::Message;

use Time::Piece;
use Moose;
use Moose::Util::TypeConstraints;

=head1 NAME

Milter::SMTPAuth::Session - SMTP Message Infomation.

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Message;

    my $message = new Milter::SMTPAuth::Message();
    $message->sender_address( 'postmaster@example.com' );
    $message->size( 1024000 ); # message size is 1024000 bytes
    $message->queue_id( 'QID123456' );
    $message->add_recipient_address( 'postmaster@example.net' );
    $message->add_recipient_address( 'webmaster@example.net' );
    $message->eom_time( time() );

    print $sess->eom_strftime( "sent:%Y-%m-%d %H:%M:%S\n" );

    printf "Sender=%s, QueueID=>%s, Size=%d\n",
           $sess->sender_address,
	       $sess->queue_id,
           $sess->size();

    print "Recipiets:\n";
    foreach my $recient ( $sess->list_recipient_addresses() ) {
        printf "%s\n", $recipient;
    }

=head1 EXPORT

=head1 SUBROUTINES/METHODS

=head2 new

=cut 

class_type 'Time::Piece';

coerce 'Time::Piece',
    from 'Int',
    via { new Time::Piece( $_ ) };


has 'connect_time'        => ( isa => 'Time::Piece',   is => 'rw', coerce => 1 );
has 'eom_time'            => ( isa => 'Time::Piece',   is => 'rw', coerce => 1 );
has 'client_address'      => ( isa => 'Maybe[Str]',    is => 'rw' );
has 'sender_address'      => ( isa => 'Maybe[Str]',    is => 'rw' );
has 'auth_id'             => ( isa => 'Maybe[Str]',    is => 'rw' );
has 'queue_id'            => ( isa => 'Maybe[Str]',    is => 'rw' );
has 'size'                => ( isa => 'Maybe[Int]',    is => 'rw' );
has 'recipient_addresses' => ( isa => 'ArrayRef[Str]',
                               is => 'rw',
                               traits  => ['Array'],
                               handles => {
                                   list_recipient_addresses => 'elements',
                                   add_recipient_address    => 'push',
                               },
                               default => sub { [] } );


=head2 client_address( $addr )

set SMTP client(remote host) IP address.

=head2 client_address()

return SMTP client(remote host) IP address. 

=head2 auth_id( $id )

set SMTP Auth ID.

=head2 auth_id()

return SMTP Auth ID.

=head2 sender_address( $addr )

set sender ( MAIL FROM: ) mail address.

=head2 sender_address()

return sender mail address.

=head2 queue_id( $id )

set queue ID.

=head2 queue_id()

return queue ID.

=head2 size( $size )

set message size(byte).

=head2 size()

return message size(byte)

=head2 add_recipient_address

set recipient ( RCPT TO: ) mail address.

=head2 list_recipient_addresses()

return recipient ( RECT To: ) mail addresses array.

=head2 recipients_count()

return recipient ( RECT To: ) mail addresses count.

=head2 connect_time( $time )

set end of message time(Time::Piece or EPOCH.

=head2 connect_time

return end of message time(Time::Piece).

=head2 eom_time( $time )

set end of message time(Time::Piece or EPOCH.

=head2 eom_time

return end of message time(Time::Piece).

=head2 clear

clear infomation except client_address, connect_time, auth_id.

=cut


sub recipients_count {
    my ( $this ) = @_;
    return int( @{ $this->recipient_addresses } );
}

sub clear {
    my ( $this ) = @_;

    $this->eom_time( 0 );
    $this->sender_address( undef );
    $this->queue_id( undef );
    $this->size( undef );
    $this->recipient_addresses( [] );
}

no Moose;
no Moose::Util::TypeConstraints;
__PACKAGE__->meta->make_immutable;


1;

