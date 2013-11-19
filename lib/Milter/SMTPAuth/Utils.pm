
package Milter::SMTPAuth::Utils;

use strict;
use warnings;
use English;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(set_effective_id);


sub set_effective_id {
    my ( $user, $group ) = @_;

    my $gid = getgrnam( $group );
    if ( $gid ) {
        $EGID = $gid;
    }
    else {
        syslog( 'err', 'not found group %s', $group );
    }

    my $uid = getpwnam( $user );
    if ( $uid ) {
        $EUID = $uid;
    }
    else {
        syslog( 'err', 'not found user %s', $user );
    }
}

1;

