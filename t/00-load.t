#!perl -T

use Test::More tests => 3;

BEGIN {
    use_ok( 'Milter::SMTPAuth::Filter' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth::Logger' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth' ) || print "Bail out!\n";
}

diag( "Testing Milter::SMTPAuth $Milter::SMTPAuth::VERSION, Perl $], $^X" );
