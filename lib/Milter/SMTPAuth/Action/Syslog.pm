
package Milter::SMTPAuth::Action::Syslog;

use Moose;
use Sys::Syslog;
with 'Milter::SMTPAuth::Action::Role';

=head1 Milter::SMTPAuth::Action::Syslog

=head1 SUBROUTINES/METHODS

=head2 new

create Action Instance.

=head2 execute( auth_id => $auth_id, score => $score, threshold => $threshold, period => $period )

send alert message to syslog.

=cut

sub execute {
    my $this = shift;
    my ( $args ) = @_;

    syslog( 'info',
	    'too many message sent by %s( %.2f points / %.2f seconds ).',
	    $args->{auth_id},
	    $args->{score},
	    $args->{period} );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

