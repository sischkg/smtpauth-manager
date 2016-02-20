
package Milter::SMTPAuth::Action::Mail;

use Moose;
use English;
use Sys::Syslog;
use Email::Simple;
use Email::Simple::Creator;
use Email::Send;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Action::Role;

with 'Milter::SMTPAuth::Action::Role';

has mailhost    => ( isa => 'Str',            is => 'ro', default  => '127.0.0.1' );
has port        => ( isa => 'Int',            is => 'ro', default  => 25 );
has sender      => ( isa => 'Str',            is => 'ro', required => 1 );
has recipients  => ( isa => 'ArrayRef[Str]',  is => 'ro', default  => sub { [] } );
has bad_senders => ( isa => 'ArrayRef[Hash]', is => 'rw', default  => sub { [] } );

=head1 Milter::SMTPAuth::Action::Mail

=head1 SUBROUTINES/METHODS

=head2 new( mailhost => $smtp_server, port => $port, seder => $sender, recipients => $recipients )

create Action Instance.

=head2 execute( auth_id => $auth_id, score => $score, threshold => $threshold, period => $period )

send alert message to syslog.

=cut

sub execute {
    my $this = shift;
    my ( $args ) = @_;

    push( @{ $this->bad_senders }, $args );
}

sub generate_message {
    my $this = shift;
    my ( $args ) = @_;

    my $template = "too many message sent by %s( %.2f points / %.2f seconds ).\r\n";
    return sprintf( $template, $args->{auth_id}, $args->{score}, $args->{period} );
}

sub pre_actions {
    my $this = shift;
    $this->clear_senders();
}

sub post_actions {
    my $this = shift;

    if ( @{ $this->bad_senders } == 0 ) {
        return;
    }

    my $body = q{};
    foreach my $bad_sender ( @{ $this->bad_senders } ) {
        $body .= $this->generate_message( $bad_sender );
    }
    $this->clear_senders();

    my $subject = "bad senders detected.";

    my $message = Email::Simple->create(
        header => [
            From    => $this->sender,
            To      => join( q{,}, @{ $this->recipients } ),
            Subject => $subject,
        ],
        body => $body, );

    my $sender = new Email::Send( { mailer => 'SMTP' } );
    $sender->mailer_args( [ Host => $this->mailhost() ] );
    my $result = $sender->send( $message );
    if ( !$result ) {
        Milter::SMTPAuth::SMTPError->throw( error_message => "cannot send mail($result)." );
    }
}

sub clear_senders {
    my $this = shift;

    @{ $this->bad_senders } = ();
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

