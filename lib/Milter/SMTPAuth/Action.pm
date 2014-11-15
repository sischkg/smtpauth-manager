
package Milter::SMTPAuth::Action;

use Moose;
use Milter::SMTPAuth::Action::Role;
use Milter::SMTPAuth::Action::Syslog;
use Milter::SMTPAuth::Action::Access;

has 'actions' => ( isa     => 'ArrayRef[Milter::SMTPAuth::Action::Role]',
		   is      => 'rw',
		   default => sub { [
		       new Milter::SMTPAuth::Action::Syslog,
		       new Milter::SMTPAuth::Action::Access,
		   ] } );


=head1 Milter::SMTPAuth::Action

=head1 SYNOPSIS

Quick summary of what the module does.

    my $action = new Milter::SMTPAuth::Action;
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


no Moose;
__PACKAGE__->meta->make_immutable;

1;
