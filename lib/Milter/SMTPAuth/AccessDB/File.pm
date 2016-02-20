package Milter::SMTPAuth::AccessDB::File;

use Moose;
use English;
use Fcntl qw(:flock);
use IO::File;
use Sys::Syslog;
use Readonly;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::AccessDB::Role;

with 'Milter::SMTPAuth::AccessDB::Role';

use constant DEFAULT_ACCESS_DB_FILENAME => '/etc/smtpauth/reject_ids.txt';

has 'filename' => ( isa => 'Str', is => 'ro', default => DEFAULT_ACCESS_DB_FILENAME );

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
    return $reject_flag_of->{$auth_id};
}

=head2 add_reject_id( $reject_id )

Add reject id to Access DB.

=cut

sub add_reject_id {
    my $this = shift;
    my ( $reject_id ) = @_;
    Milter::SMTPAuth::Utils::Lock::lock {
        my $reject_flag_of = $this->_load_access_db();
        if ( !exists( $reject_flag_of->{$reject_id} ) ) {
            my $content = join( "\n", keys( %{$reject_flag_of} ) );
            $content .= "\n";
            $content .= "$reject_id\n";
            write_to_file( $this->filename(), $content );
        }
    }
    filename => $this->_lock_filename(), lock_type => LOCK_EX;
}

sub _lock_filename {
    my $this = shift;
    return $this->filename . ".lock";
}

sub _load_access_db {
    my $this = shift;

    my %reject_flag_of;

    my $file = new IO::File( $this->filename, O_RDONLY );
    if ( !defined( $file ) ) {
        syslog( 'info', q{cannot read access db "%s"(%s).}, $this->filename, $ERRNO );
        return {};
    }

    while ( my $line = <$file> ) {
        if ( $line =~ /\A\s*(\S+)\s*\n/ ) {
            $reject_flag_of{$1} = 1;
        }
        elsif ( $line =~ /\A\s*(\S+)\s*\z/ ) {
            syslog( 'info', q{line "%s" is truncated.}, $1 );
        }
    }

    return \%reject_flag_of;
}

1;

