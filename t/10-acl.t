
use strict;
use warnings;
use Test::More qw( no_plan );
use Math::BigInt;
use Milter::SMTPAuth::Utils::ACL;

my $acl_entry;
$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '172.16.253.0/24',
    name    => 'mynetwork',
    value   => 1, );

is( $acl_entry->network, 172 * ( 2**24 ) + 16 *  ( 2**16 ) + 253 * ( 2**8 ) );
is( $acl_entry->netmask, 255 * ( 2**24 ) + 255 * ( 2**16 ) + 255 * ( 2**8 ) );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '0.0.0.0/0',
    name    => 'mynetwork',
    value   => 1, );

is( $acl_entry->network, 0 );
is( $acl_entry->netmask, 0 );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '1.2.3.4',
    name    => 'mynetwork',
    value   => 1, );

is( $acl_entry->network, 1 *   ( 2**24 ) + 2 *   ( 2**16 ) + 3 *   ( 2**8 ) + 4 );
is( $acl_entry->netmask, 255 * ( 2**24 ) + 255 * ( 2**16 ) + 255 * ( 2**8 ) + 255 );

my $acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '10.0.0.0/8',
        name    => 'private a',
        value   => 1,
    ) );

is( $acl->match( '9.255.255.254' ), undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),       '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.255.255.254' ), '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ), undef, '11.0.0.1       is unmatched 10.0.0.0/8' );

$acl = new Milter::SMTPAuth::Utils::ACL;

$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '0.0.0.0/0',
        name    => 'all address',
        value   => 1,
    ) );

ok( $acl->match( '1.0.0.1' ),      '1.0.0.1      is matched 0.0.0.0/0' );
ok( $acl->match( '172.16.10.11' ), '172.16.10.11 is matched 0.0.0.0/0' );

$acl = new Milter::SMTPAuth::Utils::ACL;

$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '172.16.10.12',
        name    => '1 address',
        value   => 1,
    ) );

is( $acl->match( '172.16.10.11' ), undef, '172.16.10.11 is unmatched 172.16.10.12/32' );
ok( $acl->match( '172.16.10.12' ), '172.16.10.12 is matched   172.16.10.12/32' );
is( $acl->match( '172.16.10.13' ), undef, '172.16.10.13 is unmatched 172.16.10.12/32' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '172.16.10.12',
        name    => '1 address',
        value   => 1,
    ) );
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '10.0.0.0/8',
        name    => 'private a',
        value   => 1,
    ) );

is( $acl->match( '172.16.10.11' ), undef, '172.16.10.11 is unmatched 172.16.10.12/32' );
ok( $acl->match( '172.16.10.12' ), '172.16.10.12 is matched   172.16.10.12/32' );
is( $acl->match( '172.16.10.13' ), undef, '172.16.10.13 is unmatched 172.16.10.12/32' );

is( $acl->match( '9.255.255.254' ), undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),       '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.255.255.254' ), '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ), undef, '11.0.0.1       is unmatched 10.0.0.0/8' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '10.16.12.0/24',
        name    => '255 address',
        value   => 2,
    ) );
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '10.0.0.0/8',
        name    => 'private a',
        value   => 1,
    ) );

is( $acl->match( '9.255.255.254' ), undef, '9.255.255.254  is unmatched 10.0.0.0/8' );
ok( $acl->match( '10.0.0.1' ),       '10.0.0.1       is matched   10.0.0.0/8' );
ok( $acl->match( '10.15.255.254' ),  '10.15.255.254  is matched   10.0.0.0/8' );
ok( $acl->match( '10.16.12.1' ),     '10.16.12.1     is matched   10.16.0.0/24' );
ok( $acl->match( '10.16.12.254' ),   '10.16.12.254   is matched   10.16.0.0/24' );
ok( $acl->match( '10.255.255.254' ), '10.255.255.254 is matched   10.0.0.0/8' );
is( $acl->match( '11.0.0.1' ), undef, '11.0.0.1       is unmatched 10.0.0.0/8' );

is( $acl->match( '10.0.0.1' )->name,       "private a",   '10.0.0.1       is matched   10.0.0.0/8' );
is( $acl->match( '10.15.255.254' )->name,  "private a",   '10.15.255.254  is matched   10.0.0.0/8' );
is( $acl->match( '10.16.12.1' )->name,     "255 address", '10.16.12.1     is matched   10.16.12.0/248' );
is( $acl->match( '10.16.12.254' )->name,   "255 address", '10.16.12.254   is matched   10.16.12.0/248' );
is( $acl->match( '10.16.13.1' )->name,     "private a",   '10.16.13.1     is matched   10.0.0.0/8' );
is( $acl->match( '10.255.255.254' )->name, "private a",   '10.255.255.254 is matched   10.0.0.0/8' );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '1::/64',
    name    => 'mynetwork',
    value   => 1, );

is( $acl_entry->network, Math::BigInt->new( 1 )->blsft( 112 ), "prefix  of 1::/64" );
is( $acl_entry->netmask,
    Math::BigInt->new( 1 )->blsft( 128 ) - Math::BigInt->new( 1 )->blsft( 64 ),
    "netmask of 1::/64" );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '1::1/128',
    name    => 'myhost',
    value   => 1, );

is( $acl_entry->network, Math::BigInt->new( 1 )->blsft( 112 ) + 1, "prefix  of 1::1/128" );
is( $acl_entry->netmask, Math::BigInt->new( 1 )->blsft( 128 ) - 1, "netmask of 1::1/128" );

$acl_entry = new Milter::SMTPAuth::Utils::ACLEntry(
    address => '::0/0',
    name    => 'default route',
    value   => 1, );

is( $acl_entry->network, 0, "prefix  of ::0/0" );
is( $acl_entry->netmask, 0, "netmask of ::0/0" );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '2000::/32',
        name    => 'my network',
        value   => 1,
    ) );

is( $acl->match( '::1' ), undef, '::1 is unmatched 2000::/32' );
is( $acl->match( '1fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ),
    undef, '1fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff is unmatched 2000::/32' );
is( $acl->match( '2000::1' )->value, 1, '2000::1 is matched 2000::/32' );
is( $acl->match( '2000:0000:ffff:ffff:ffff:ffff:ffff:ffff' )->value,
    1, '2000:0000:ffff:ffff:ffff:ffff:ffff:ffff is matched 2000::/32' );
is( $acl->match( '2000:0001::' ), undef, '2000:0001:: is unmatched 2000::/32' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '2000::3/128',
        name    => 'my network',
        value   => 1,
    ) );

is( $acl->match( '2000::2' ),        undef, '2000:2 is unmatched 2000::3/128' );
is( $acl->match( '2000::3' )->value, 1,     '2000::3 is matched 2000::3/128' );
is( $acl->match( '2000::4' ),        undef, '2000::4 is unmatched 2000::/128' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '::0/0',
        name    => 'default route',
        value   => 1,
    ) );

is( $acl->match( '::1' )->value, 1, '::1 is matched default route' );
is( $acl->match( 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' )->value,
    1, 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff is matched default route' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '1000::/32',
        name    => 'my network',
        value   => 1,
    )
    )->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '2000::/32',
        name    => 'neighbor network',
        value   => 2,
    ) );

is( $acl->match( '0fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ),
    undef, '0fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff is unmatched 1000::32 nor 2000::/32' );
is( $acl->match( '1000::1' )->value, 1, '1000::1 is matched 1000::/32' );
is( $acl->match( '1000:0000:ffff:ffff:ffff:ffff:ffff:ffff' )->value,
    1, '1000:0000:ffff:ffff:ffff:ffff:ffff:ffff is matched 1000::/32' );
is( $acl->match( '1000:0001::1' ), undef, '1000:0001::1 is unmatched 1000::/32 nor 2000::/32' );

is( $acl->match( '1fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ),
    undef, '1fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff is unmatched 1000::32 nor 2000::/32' );
is( $acl->match( '2000::1' )->value, 2, '2000::1 is matched 2000::/32' );
is( $acl->match( '2000:0000:ffff:ffff:ffff:ffff:ffff:ffff' )->value,
    2, '2000:0000:ffff:ffff:ffff:ffff:ffff:ffff is matched 2000::/32' );
is( $acl->match( '2000:0001::1' ), undef, '2000:0001::1 is unmatched 1000::/32 nor 2000::/32' );

$acl = new Milter::SMTPAuth::Utils::ACL;
$acl->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '1000::/32',
        name    => 'my network',
        value   => 1,
    )
    )->add(
    new Milter::SMTPAuth::Utils::ACLEntry(
        address => '1000::/96',
        name    => 'core network',
        value   => 2,
    ) );

is( $acl->match( '0fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff' ),
    undef, '0fff:ffff:ffff:ffff:ffff:ffff:ffff:ffff is unmatched 1000::32 nor 1000::/96' );
is( $acl->match( '1000::1' )->value,              2, '1000::1 is matched 1000::/96' );
is( $acl->match( '1000::ffff:ffff' )->value,      2, '1000::ffff:ffff is matched 1000::/32' );
is( $acl->match( '1000::0001:0000:0000' )->value, 1, '1000::0001:0000:0000 is matched 1000::/32' );
is( $acl->match( '1000:0000:ffff:ffff:ffff:ffff:ffff:ffff' )->value,
    1, '1000:0000::ffff:ffff:ffff:ffff:ffff:ffff is matched 1000::/32' );
is( $acl->match( '2000:0001::1' ), undef, '1000:0001:: is unmatched 1000::/32 nor 2000::/32' );

