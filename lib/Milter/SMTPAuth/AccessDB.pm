
package Milter::SMTPAuth::AccessDB;

use Moose;
use Moose::Util::TypeConstraints;
use Milter::SMTPAuth::AccessDB::Role;
use Milter::SMTPAuth::AccessDB::File;

role_type 'Milter::SMTPAuth::AccessDB::Role';

has 'access_databases' => (
    isa     => 'ArrayRef[Milter::SMTPAuth::AccessDB::Role]',
    is      => 'rw',
    default => sub {
        [ new Milter::SMTPAuth::AccessDB::File, ];
    }, );

=head1 Milter::SMTPAuth::AccessDB

=head1 SUBROUTINES/METHODS

=head2 new

Create AccessDB manager instance.

=head2 add_database( $db )

Add AccessDB to manager. AccessDB instance has Milter::SMTPAuth::AccessDB::Role.

=cut

sub add_database {
    my $this = shift;
    my ( $db ) = @_;

    push( @{ $this->access_databases }, $db );
}

=head2 is_reject( $auth_id )

decide whether the mail is rejected.

=cut

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
