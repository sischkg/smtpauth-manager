package Milter::SMTPAuth::AccessDB;

use strict;
use warnings;
use English;
use Fcntl qw(:flock);
use Readonly;

Readonly::Scalar my $DEFAULT_ACCESS_DB_FILENAME => '/etc/smtpauth/reject_ids.txt';


=head1 NAME

Milter::SMTPAuth::AccessDB

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

reject mail whichi is sent by SMTP Auth ID.

    use Milter::SMTPAuth::AccessDB;

    my $access_db = new Milter::SMTPAuth::AccessDB( '/etc/mail/auth_access' );

    ...
  
    $access_db->is_reject( "spam" ); 

=head1 SUBROUTINES/METHODS

=head2 new( filename => $filename )

Create Instance. $filename is Access DB Filename.

=cut

sub new {
	my $class = shift;
	my ( $access_db_filename ) = @_;

	if ( ! defined( $access_db_filename ) ) {
		$access_db_filename = $DEFAULT_ACCESS_DB_FILENAME;
	}

	my $this = {
		access_db_fililename => $access_db_filename,
	};

	bless( $this, $class );
}

=head2 is_reject( $auth_id )

If access db file includes $auth_id, this method returns true.

=cut

sub is_reject {
	my $this = shift;
	my ( $auth_id ) = @_;

	my $reject_flag_of = $this->_load_access_db();
	return $reject_flag_of->{ $auth_id };
}


sub _load_access_db {
	my $this = shift;

	my $access_db = new IO::File( $this->{access_db_filename} );
	if ( ! defined( $access_db ) ) {	
		return {};
	}

	my %reject_flag_of;

	eval {
		flock( $access_db, LOCK_SH );

		while ( my $line = <$access_db> ) {
			chomp $line;
			$line =~ s/\#.*\z//g;
			if ( $line =~ /\A\s*(\S+)\s*\z/ ) {
				$reject_flag_of{ $1 } = 1;
			}
		}
	};

	$access_db->close();

	return \%reject_flag_of;
}



=head1 AUTHOR

Toshifumi Sakaguchi, C<< <sischkg at gmail.com> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Milter::SMTPAuth::Filter


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

1; # End of Milter::SMTPAuth::Filter
