
use strict;
use warnings;
use Test::More qw( no_plan );
use Milter::SMTPAuth::Utils::ACL;


my $acl_entry;
$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    network    => '172.16.253.0',
    bit_length => 24,
    name       => 'mynetwork',
    value      => 1,
);

is( 172 * (2**24) +  16 * (2**16) + 253 * (2**8), $acl_entry->network );
is( 255 * (2**24) + 255 * (2**16) + 255 * (2**8), $acl_entry->netmask );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    network    => '0.0.0.0',
    bit_length => 0,
    name       => 'mynetwork',
    value      => 1,
);

is( 0, $acl_entry->network );
is( 0, $acl_entry->netmask );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    network    => '1.2.3.4',
    bit_length => 32,
    name       => 'mynetwork',
    value      => 1,
);

is(   1 * (2**24) +   2 * (2**16) +   3 * (2**8) +   4, $acl_entry->network );
is( 255 * (2**24) + 255 * (2**16) + 255 * (2**8) + 255, $acl_entry->netmask );


my $acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '10.0.0.0',
	bit_length => 8,
	name       => 'private a',
	value      => 1,
    )
);

is( $acl->match( '9.255.255.254' ),  undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),              '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.255.255.254' ),        '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ),       undef, '11.0.0.1       is unmatched 10.0.0.0/8' );

$acl = new Milter::SMTPAuth::Utils::ACL;

$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '0.0.0.0',
	bit_length => 0,
	name       => 'all address',
	value      => 1,
    )
);

ok( $acl->match( '1.0.0.1' ),      '1.0.0.1      is matched 0.0.0.0/0' );
ok( $acl->match( '172.16.10.11' ), '172.16.10.11 is matched 0.0.0.0/0' );

$acl = new Milter::SMTPAuth::Utils::ACL;

$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '172.16.10.12',
	bit_length => 32,
	name       => '1 address',
	value      => 1,
    )
);

is( $acl->match( '172.16.10.11' ), undef, '172.16.10.11 is unmatched 172.16.10.12/32' );
ok( $acl->match( '172.16.10.12' ),        '172.16.10.12 is matched   172.16.10.12/32' );
is( $acl->match( '172.16.10.13' ), undef, '172.16.10.13 is unmatched 172.16.10.12/32' );


$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '172.16.10.12',
	bit_length => 32,
	name       => '1 address',
	value      => 1,
    )
);
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '10.0.0.0',
	bit_length => 8,
	name       => 'private a',
	value      => 1,
    )
);

is( $acl->match( '172.16.10.11' ), undef, '172.16.10.11 is unmatched 172.16.10.12/32' );
ok( $acl->match( '172.16.10.12' ),        '172.16.10.12 is matched   172.16.10.12/32' );
is( $acl->match( '172.16.10.13' ), undef, '172.16.10.13 is unmatched 172.16.10.12/32' );

is( $acl->match( '9.255.255.254' ),  undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),              '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.255.255.254' ),        '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ),       undef, '11.0.0.1       is unmatched 10.0.0.0/8' );


$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '10.16.12.0',
	bit_length => 24,
	name       => '255 address',
	value      => 2,
    )
);
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
	network    => '10.0.0.0',
	bit_length => 8,
	name       => 'private a',
	value      => 1,
    )
);

is( $acl->match( '9.255.255.254' ),  undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),              '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.15.255.254' ),         '10.15.255.254  is matched   10.0.0.0/8' );
ok( $acl->match( '10.16.12.1' ),            '10.16.12.1     is matched   10.16.0.0/24' );
ok( $acl->match( '10.16.12.254' ),          '10.16.12.254   is matched   10.16.0.0/24' );
ok( $acl->match( '10.255.255.254' ),        '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ),       undef, '11.0.0.1       is unmatched 10.0.0.0/8' );

is( $acl->match( '10.0.0.1' )->name,       "private a",   '10.0.0.1       is matched   10.0.0.0/8' );
is( $acl->match( '10.15.255.254' )->name,  "private a",   '10.15.255.254  is matched   10.0.0.0/8' );
is( $acl->match( '10.16.12.1' )->name,     "255 address", '10.16.12.1     is matched   10.16.12.0/248' );
is( $acl->match( '10.16.12.254' )->name,   "255 address", '10.16.12.254   is matched   10.16.12.0/248' );
is( $acl->match( '10.16.13.1' )->name,     "private a",   '10.16.13.1     is matched   10.0.0.0/8' );
is( $acl->match( '10.255.255.254' )->name, "private a",   '10.255.255.254 is matched   10.0.0.0/8' );


