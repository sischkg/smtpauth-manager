package Milter::SMTPAuth::AccessDB::File;

use English;
use Fcntl qw(:flock);
use IO::File;
use Sys::Syslog;
use Readonly;
use Moose;
with 'Milter::SMTPAuth::AccessDB::Role';

Readonly::Scalar my $DEFAULT_ACCESS_DB_FILENAME => '/etc/smtpauth/reject_ids.txt';

has 'filename' => ( isa => 'Str', is => 'ro', default => $DEFAULT_ACCESS_DB_FILENAME );

=head1 NAME

Milter::SMTPAuth::AccessDB::File

=head1 SYNOPSIS

reject mail whichi is sent by SMTP Auth ID.

    use Milter::SMTPAuth::AccessDB::File;

    my $access_db = new Milter::SMTPAuth::AccessDB::File( filename => '/etc/mail/auth_access' );

    ...

    $access_db->is_reject( "spam" );

=head1 SUBROUTINES/METHODS

=head2 new( filename => $filename )

Create Instance. $filename is Access DB Filename.

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

    my $access_db = new IO::File( $this->filename() );
    if ( ! defined( $access_db ) ) {
	syslog( 'err', 'cannot open access db %s(%s).', $this->{access_db_filename}, $ERRNO );
	return {};
    }

    my %reject_flag_of;

    eval {
	flock( $access_db, LOCK_SH );

	while ( my $line = <$access_db> ) {
	    if ( $line =~ /\A\s*(\S+)\s*\n/ ) {
		$reject_flag_of{ $1 } = 1;
	    }
	    elsif ( $line =~ /\A\s*(\S+)\s*\z/ ) {
		syslog( 'info', q{line "%s" is truncated.}, $1 );
            }
	}
    };
    if ( my $error = $EVAL_ERROR ) {
        syslog( 'err', q{read AccessDB error(%s).}, $error );
    }

    $access_db->close();

    return \%reject_flag_of;
}

1;
