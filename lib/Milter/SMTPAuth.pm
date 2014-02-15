package Milter::SMTPAuth::Child;

use Moose;

has 'pid'         => ( isa => 'Maybe[Int]',    is => 'rw', default  => undef );
has 'command'     => ( isa => 'Str',           is => 'ro', required => 1 );
has 'arguments'   => ( isa => 'ArrayRef[Str]', is => 'ro', required => 1 );
has 'stop_signal' => ( isa => 'Int',           is => 'ro', default  => 3 ); # default signal is SIGQUIT

sub start {
    my ( $this ) = @_;
    my $pid = fork();
    if ( $pid ) {
        $this->pid( $pid );
        return;
    }
    else {
        exec( $this->command, @{ $this->arguments } );
    }
}

no Moose;
__PACKAGE__->meta->make_immutable;

package Milter::SMTPAuth;

use Moose;
use English;
use Sys::Syslog;
use POSIX ":sys_wait_h";
use Milter::SMTPAuth::Exception;

has 'processes'   => ( isa => 'ArrayRef[Milter::SMTPAuth::Child]', is => 'ro', required => 1 );
has 'is_continue' => ( isa => 'Bool', is => 'rw', default => 1 );

=head1 NAME

Milter::SMTPAuth - management child processes.

=head1 VERSION

=cut

our $VERSION = "0.1.1";

=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth;

    my $logger = new Milter::SMTPAuth::Child(
        command   => 'smtpauth-log-collector',
        arguments => [ '--listen_path', '/var/run/smtpauth-log-collector.sock',
                       '--log',         '/var/log/smtpauth.log' ],
    );

    my $filter = new Milter::SMTPAuth::Child(
        command   => 'smtpauth-filter',
        arguments => [ '--listen_path', '/var/run/smtpauth-filter.sock',
                       '--logger_path', '/var/run/smtpauth-log-collector.sock', ]
    );

    my $manager = new Milter::SMTPAuth(
        processes => [ $logger, $filter ],
    );

    $manager->start();

    ...

    $manager->stop();

=head1 SUBROUTINES/METHODS

=head2 new

create manager instance. 

=over 4

=item * processes

ArrayRef of Milter::SMTPAuth::Child.

=back

=cut

=head2 start

run service.

=cut

sub start {
    my ( $this ) = @_;

    $SIG{CHLD} = sub {
        print "recv SIGCHLD\n";
        while ( ( my $kid = waitpid( -1, WNOHANG ) ) > 0 ) {
            foreach my $process ( @{ $this->processes() } ) {
                if ( $kid == $process->pid ) {
                    $process->pid( undef );
                }
            }
        }
    };

    for ( ; $this->is_continue() ; sleep( 100 ) ) {
        eval {
            foreach my $process ( @{ $this->processes() } ) {
                if ( ! defined( $process->pid() ) ) {
                    $process->start();
                }
            }
        };
        if ( my $error = $EVAL_ERROR ) {
            syslog( 'err', 'start child error %s', $error );
        }
    }

    syslog( 'info', 'stopping service' );
    # end servide
    foreach my $process ( @{ $this->processes() } ) {
        syslog( 'info', 'stopping %s, pid: %d', $process->command(), $process->pid() );
        kill( $process->stop_signal(), $process->pid() ); # send signal SIGUSR1
        waitpid( $process->pid(), WUNTRACED );
        syslog( 'info', 'stopped %s', $process->command() );
    }

}

=head2 stop

stop all children.

=cut

sub stop {
    my ( $this ) = @_;

    $this->is_continue( 0 );
}




no Moose;
__PACKAGE__->meta->make_immutable;

=head1 AUTHOR

Toshifumi Sakaguchi, C<< <sischkg at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Milter::SMTPAuth

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Milter-SMTPAuth>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Milter-SMTPAuth>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Milter-SMTPAuth>

=item * Search CPAN

L<http://search.cpan.org/dist/Milter-SMTPAuth/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Toshifumi Sakaguchi.

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/bsd-license.php>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of Toshifumi Sakaguchi's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Milter::SMTPAuth
