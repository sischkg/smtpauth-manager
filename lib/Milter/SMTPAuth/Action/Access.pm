
package Milter::SMTPAuth::Action::Access;

use Moose;
use Sys::Syslog;
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

    syslog( 'info', q{add auth id "%s" to access db.}, $args->{auth_id} );
    $access_db->add_reject_id( $args->{auth_id} );
}

sub pre_actions {

}

sub post_actions {

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;

