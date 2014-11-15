
package Milter::SMTPAuth::Action::Access;

use Moose;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::AccessDB::File;
use Milter::SMTPAuth::Action::Role;

with 'Milter::SMTPAuth::Action::Role';

has filename => ( isa     => 'Str',
		  is      => 'ro',
		  default => Milter::SMTPAuth::AccessDB::File::DEFAULT_ACCESS_DB_FILENAME );

sub execute {
    my $this = shift;
    my ( $args ) = @_;

    my $access_db = new Milter::SMTPAuth::AccessDB::File(
	filename => $this->filename
    );

    $access_db->add_reject_id( $args->{auth_id} );
}

1;

