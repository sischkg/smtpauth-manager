# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::Client;

use Moose;
use English;
use IO::Socket::UNIX;
use Storable qw( nfreeze );
use Milter::SMTPAuth::Exception;

has 'listen_path' => ( isa => 'Str', is => 'rw', required => 1 );

=head1 NAME

Milter::SMTPAuth::Logger::Client - Send Milter::SMTPAuth::Filter statistics log.

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Logger::Client;

    my $logger = new Milter::SMTPAuth::Logger::Client(
        listen_path => '/var/run/smtpauth-filter-logger',
    );

    my $message = new Milter::SMTPAuth::Message;
    $logger->send( $message );


=head1 SUBROUTINES/METHODS

=head2 new

create Logger instance.

=head2 send

send log to server.

=cut

sub send {
  my $this = shift;
  my ( $message ) = @_;

  my $socket = new IO::Socket::UNIX( Type => SOCK_STREAM,
									 Peer => $this->listen_path );
  if ( ! defined( $socket ) ) {
	my $error = sprintf( 'cannot open Logger socket "%s"(%s)',
						 $this->listen_path,
						 $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
  }

  my $data = nfreeze( $message );
  if ( ! $socket->print( $data ) ) {
	eval {
	  $socket->close();
	};
	my $error = sprintf( 'cannot output log to socket(%s).', $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
  }

  $socket->close();
}

=head1 AUTHOR

Toshifumi Sakaguchi, C<< <sischkg at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Milter::SMTPAuth::Logger

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Milter-SMTPAuth-Filter>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Milter-SMTPAuth-Filter>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Milter-SMTPAuth-Filter>

=item * Search CPAN

L<http://search.cpan.org/dist/Milter-SMTPAuth-Filter/>

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

1;

