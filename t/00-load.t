#!perl -T

use Test::More;

BEGIN {
    use_ok( 'Milter::SMTPAuth::Filter' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth::Logger' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth::AccessDB' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth::AccessDB::File' ) || print "Bail out!\n";
    use_ok( 'Milter::SMTPAuth' ) || print "Bail out!\n";
}

diag( "Testing Milter::SMTPAuth $Milter::SMTPAuth::VERSION, Perl $], $^X" );

done_testing;

