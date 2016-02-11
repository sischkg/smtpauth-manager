
package Milter::SMTPAuth::Action::Mail;

use Moose;
use Sys::Syslog;
use Email::Simple;
use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP qw();
use Milter::SMTPAuth::Action::Role;

with 'Milter::SMTPAuth::Action::Role';

has host        => ( is => 'Str',            isa => 'ro', default  => '127.0.0.1' );
has port        => ( is => 'Int',            isa => 'ro', default  => 25 );
has sender      => ( is => 'Str',            isa => 'ro', required => 1 );
has recipients  => ( is => 'ArrayRef[Str]',  isa => 'ro', default  => sub { [] } );
has bad_senders => ( is => 'ArrayRef[Hash]', isa => 'ow', default  => sub { [] } );

=head1 Milter::SMTPAuth::Action::Mail

=head1 SUBROUTINES/METHODS

=head2 new( host => $smtp_server, port => $port, seder => $sender, recipients => $recipients )

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
    $this = shift;

    my $body = q{};
    foreach my $bad_sender ( @{ $this->bad_sernders } ) {
	$body .= $this->generate_message( $bad_senders );
    }
    $this->clear_senders();

    my $subject = "bad senders detected.";

    my $message = Email::Simple::create(
					header => [
						   From    => $this->sender,
						   To      => $this->recipients,
						   Subject => $subject,
						  ],
					body => $body,
				       );

    eval {
	sendmail( $message,
		  {
		   from      => $this->sender,
		   to        => $this->recipients,
		   transport => new Email::Sender::Transport::SMTP({
								    host => $this->mailhost,
								    port => $this->port,
								   }),
		  },
		);
    };
    if ( my $error = $EVAL_ERROR ) {
	SMTPError->throw( "cannot send mail($error)." );
    }
}


sub clear_senders {
    my $this = shift;

    @{ $this->bad_senders } = ();
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;

