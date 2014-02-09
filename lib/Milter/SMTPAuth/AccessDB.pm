package Milter::SMTPAuth::AccessDB::Role;

use Moose::Role;
requires 'is_reject';


package Milter::SMTPAuth::AccessDB;

use Moose;
use Moose::Util::TypeConstraints;

role_type 'Milter::SMTPAuth::AccessDB::Role';

has 'access_databases' => ( isa     => 'ArrayRef[Milter::SMTPAuth::AccessDB::Role]',
			    is      => 'rw',
			    default => sub { [] }, );

sub add_database {
    my $this = shift;
    my ( $db ) = @_;

    push( @{ $this->access_databases }, $db );
}

sub is_reject {
    my $this = shift;
    my ( $auth_id ) = @_;

    foreach my $db ( @{ $this->access_databases } ) {
	if ( $db->is_reject( $auth_id ) ) {
	    return 1;
	}
    }

    return 0;
}

1;
