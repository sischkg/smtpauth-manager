package Milter::SMTPAuth::AccessDB::Memory;

use English;
use Fcntl qw(:flock);
use IO::Memory;
use Sys::Syslog;
use Readonly;
use Moose;
with 'Milter::SMTPAuth::AccessDB::Role';

has 'reject_ids' => ( isa => 'HashRef[Str]', is => 'ro', default => sub { {} } );

=head1 NAME

Milter::SMTPAuth::AccessDB::Memory

=head1 SYNOPSIS

reject mail whichi is sent by SMTP Auth ID.

    use Milter::SMTPAuth::AccessDB::Memory;

    my $access_db = new Milter::SMTPAuth::AccessDB::Memory(
       {
           spammer => 1,
           bommer  => 1,
       }
    );

    ...

    if ( $access_db->is_reject( "spammer" ) ) {
        ...
    }

=head1 SUBROUTINES/METHODS

=head2 new( { id1 => 1, id2 =>   )

Create Instance. id1, id2, ... are reject SMTP Auth IDs.

=head2 is_reject( $auth_id )

If access db includes $auth_id, this method returns true.

=cut

sub is_reject {
    my $this = shift;
    my ( $auth_id ) = @_;

    return = $this->access_ids->{$auth_id};
}

1;
