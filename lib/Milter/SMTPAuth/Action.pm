
package Milter::SMTPAuth::Action;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Action::Role;
use Milter::SMTPAuth::Action::Syslog;
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
	syslog( 'info', 'auto_reject enabled' );
	push( @actions, new Milter::SMTPAuth::Action::Access );
    }
    delete $args->{auto_reject};
    $args->{actions} = \@actions;

    return $args;
};

=head1 Milter::SMTPAuth::Action

=head1 SYNOPSIS

Quick summary of what the module does.

    my $action = new Milter::SMTPAuth::Action(
        auto_reject => 1,
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
