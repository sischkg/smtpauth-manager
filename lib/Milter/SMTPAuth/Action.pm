
package Milter::SMTPAuth::Action;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Action::Role;
use Milter::SMTPAuth::Action::Syslog;
use Milter::SMTPAuth::Action::Mail;
use Milter::SMTPAuth::Action::Access;
use Data::Dumper;

has 'actions' => ( isa => 'ArrayRef[Milter::SMTPAuth::Action::Role]',
		   is  => 'rw' );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig( @_ );

    my @actions = ( new Milter::SMTPAuth::Action::Syslog );

    if ( $args->{auto_reject} ) {
	syslog( 'info', 'auto_reject is enabled' );
	push( @actions, new Milter::SMTPAuth::Action::Access );
    }
    if ( $args->{alert_email} ) {
	my $mailhost   = $args->{alert_mailhost};
	my $port       = $args->{alert_port};
	my $sender     = $args->{alert_sender};
	my $recipients = $args->{alert_recipients};

	if ( $mailhost && $port && $sender && $recipients ) {
	    my $alert_mail = new Milter::SMTPAuth::Action::Mail( host       => $mailhost,
								 port       => $port,
								 sender     => $sender,
								 recipients => $recipients );
	    syslog( 'info', 'email alert is enabled. mailhost: %s, port: %d, sender: %s.' );
	    foreach my $recipient ( @{ $recipients } ) {
		syslog( 'info', 'email alert recipient: %s.', $recipient );
	    }
	    push( @actions, $alert_mail );
	}
	else {
	    my $msg = "when alert_mail is enabled, ";
	    if ( ! defined( $mailhost ) )   { $msg .= "alert_mailhost " }
	    if ( ! defined( $port ) )       { $msg .= "alert_port " }
	    if ( ! defined( $sender ) )     { $msg .= "alert_sender " }
	    if ( ! defined( $recipients ) ) { $msg .= "alert_recipients "; }
	    $msg .= " must be specified.";
	    Milter::SMTPAuth::ArgumentError->throw( error_message => $msg );
	}
    }
    delete $args->{auto_reject};
    delete $args->{alert_email};
    delete $args->{alert_mailhost};
    delete $args->{alert_port};
    delete $args->{alert_sender};
    delete $args->{alert_recipients};

    $args->{actions} = \@actions;
    return $args;
};

=head1 Milter::SMTPAuth::Action

=head1 SYNOPSIS

Quick summary of what the module does.

    my $action = new Milter::SMTPAuth::Action(
        auto_reject     => 1,
        alert_email     => 1,
        alert_mailhost  => 'mailhost.example.com',
        alert_port      => 587,
        alert_sender    => 'postmaster@example.com',
        alert_recpients => [ 'admin@example.com', ],
    );
    $action->execute( { auth_id   => 'spammer',
                        score     => 10000,
                        threshold => 200,
                        period    => 60 } );


=head1 SUBROUTINES/METHODS

=head2 new

create Action Instance.

=head2 execute( auth_id => $auth_id, score => $score, threshold => $threshold )

=cut

sub execute {
    my $this = shift;
    my ( $args ) = @_;

    foreach my $action ( @{ $this->actions() } ) {
	$action->execute( $args );
    }
}


sub pre_actions {
    my $this = shift;
    foreach my $action ( @{ $this->actions() } ) {
	$action->pre_actions();
    }
}

sub post_actions {
    my $this = shift;
    foreach my $action ( @{ $this->actions() } ) {
	$action->post_actions();
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
