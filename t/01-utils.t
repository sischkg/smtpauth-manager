
use strict;
use warnings;
use Test::More qw( no_plan );
use Milter::SMTPAuth::Utils;

my $result;
$result = match_ip_address( '1.20.30.40' );
ok( $result, 'matched' );
is( $result->{address}, '1.20.30.40',   'address is matched entire string' );
is( $result->{octet_1}, '1',            'octet_1 is matched' );
is( $result->{octet_2}, '20',           'octet_2 is matched' );
is( $result->{octet_3}, '30',           'octet_3 is matched' );
is( $result->{octet_4}, '40',           'octet_4 is matched' );
ok( ! defined( $result->{bit_length} ), 'bit length does not exist' );

$result = match_ip_address( '10.20.30.40/24' );
ok( $result, 'matched' );
is( $result->{address},    '10.20.30.40', 'address is matched entire string' );
is( $result->{octet_1},    '10',          'octet_1 is matched' );
is( $result->{octet_2},    '20',          'octet_2 is matched' );
is( $result->{octet_3},    '30',          'octet_3 is matched' );
is( $result->{octet_4},    '40',          'octet_4 is matched' );
is( $result->{bit_length}, '24',          'bit length is match' );


