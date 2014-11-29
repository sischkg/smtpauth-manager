
package Milter::SMTPAuth::Utils::ACLEntry;

use Moose;
use Scalar::Util qw(looks_like_number);
use Net::IP;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Utils;
use Math::BigInt;
use Data::Dumper;

has 'address' => ( isa => 'Net::IP',    is => 'ro', required => 1 );
has 'name'    => ( isa => 'Maybe[Str]', is => 'ro' );
has 'value'   => ( isa => 'Any',        is => 'rw' );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my $args  = $class->$orig( @_ );

    if ( ! exists( $args->{address} ) ) {
	Milter::SMTPAuth::ArugmentError->throw(
	    error_message => "new Milter::SMTPAuth::Utils::ACLEntry must be specified address.",
	);
    }

    if ( ! defined( blessed( $args->{address} ) ) ) {
	$args->{address} = new Net::IP( $args->{address} );
	if ( ! $args->{address} ) {
	    Milter::SMTPAuth::ArugmentError->throw(
		error_message => q{address must be Net::IP instance or "network/netmask" string},
	    );
	}
    }

    return $args;
};

=head1 NAME

Milter::SMTPAuth::Utils::ACLEntry - Network ACL entry.

=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth::Utils::ACL;

    my $my_network = new Milter::SMTPAuth::Utils::ACLEntry(
        address => '172.16.10.0/24',
        name    => 'my network',
        value   => 1,
    );


=head1 SUBROUTINES/METHODS

=head2 new

=over 4

=item * address

Net::IP instance.

=item * name

Network name.

=item * value

=back

=head2 network

=cut

sub network {
    my $this = shift;
    return new Math::BigInt( $this->address()->intip() );
}

=head2 netmask

=cut

sub netmask {
    my $this = shift;

    my $bit_length = $this->version() == 4 ? 32 : 128;
    return bit_n( $bit_length ) - bit_n( $bit_length - $this->address()->prefixlen() );
}


=head2 bit_n( $n )

return 0x01 << $n by Math::BigInt. if $n < 0 return 0.

=cut

sub bit_n {
    my ( $n ) = @_;

    if ( $n >= 0 ) {
	return Math::BigInt->new( 1 )->blsft( $n );
    }
    else {
	return Math::BigInt->new( 0 );
    }
}

=head2 version

If network address is IPv4, return 4. If network address is IPv6, return 6.

=cut

sub version {
    my $this = shift;

    return $this->address->version();
}

=head2 check_ip_address( $str )

Check $str is IP address format, and return Net::IP instance.
If $str is not IP address format, throw ArgumentError exception.

=cut

sub check_ip_address {
    my ( $str ) = @_;

    my $ip_addr = new Net::IP( $str );
    if ( ! defined( $ip_addr ) ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => sprintf( q{Invalid network address "%s"(%s).}, $str, Net::IP::Error() ),
	);
    }
    return $ip_addr;
}


no Moose;
__PACKAGE__->meta->make_immutable;


package Milter::SMTPAuth::Utils::ACLBit;

use Moose;

has 'bit'    => ( isa      => 'Int',
		  is       => 'ro',
		  required => 1 );
has 'next_0' => ( isa     => 'Maybe[Milter::SMTPAuth::Utils::ACLBit]',
		  is      => 'rw',
		  default => undef );
has 'next_1' => ( isa => 'Maybe[Milter::SMTPAuth::Utils::ACLBit]',
		  is  => 'rw',
		  default => undef );
has 'acl_entry' => ( isa     => 'Maybe[Milter::SMTPAuth::Utils::ACLEntry]',
		     is      => 'rw',
		     default => undef );

sub print_acl_bit {
    my $this = shift;

    printf STDERR "bit %d, next_1: %d, next_0: %d, acl_entry: %s\n",
	$this->bit, $this->next_1 ? 1 : 0, $this->next_0 ? 1 : 0, $this->acl_entry ? $this->acl_entry->name : "none";
}

no Moose;
__PACKAGE__->meta->make_immutable;


=head1 NAME

Milter::SMTPAuth::Utils::ACL - ACL.

=head1 VERSION

=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth::Utils::ACL;

    my $my_network = new Milter::SMTPAuth::Utils::ACLEntry(
        address => '172.16.10.0/24',
        name    => 'my network',
        value   => 1,
    );

    my $group_network = new Milter::SMTPAuth::Utils::ACLEntry(
        address    => '172.16.10.0/16',
        name       => 'group network',
        value      => 2,
    );

    my $my_host = new Milter::SMTPAuth::Utils::ACLEntry(
        address    => '172.16.10.101',
        name       => 'my host',
        value      => 0,
    );

    # make ACL.
    my $acl = new Milter::SMTPAuth::Utils::ACL;
    $acl->add( $my_network );
    $acl->add( $group_network );
    $acl->add( $my_host );

    $acl->match( '10.0.0.1' );                      # unmatched, return undef.

    my $acl_entry1 = $acl->match( '172.16.230.24' ) # matched $group_network, return $group_network.
    print $acl_entry1->name;                        # "group network"

    my $acl_entry2 = $acl->match( '172.16.10.24' )  # matched $my_network, return $my_network.
    print $acl_entry2->name;                        # "my network"

    my $acl_entry3 = $acl->match( '172.16.10.101' ) # matched $my_host, return $my_host.
    print $acl_entry3->name;                        # "my host"

=cut

package Milter::SMTPAuth::Utils::ACLImp;

use Moose;
use Data::Dumper;

has '_top' => ( isa     => 'Milter::SMTPAuth::Utils::ACLBit',
		is      => 'ro',
		default => sub { new Milter::SMTPAuth::Utils::ACLBit( bit => 0 ) } );
has '_bit_length' => ( isa      => 'Int',
		       is       => 'ro',
		       required => 1 );


=head1 SUBROUTINES/METHODS

=head2 new( _bit_length => $bit_length )

Bit length of IP address, Bit length of IPv4 address length is 32, bit length of IPv6 address is 128.

=head2 add( $acl_entry )

add acl_entry, and return self.

=cut

sub add {
    my $this = shift;
    my ( $ac ) = @_;

    my $node = $this->_top();
    for ( my $i = 1 ; $i <= $this->_bit_length + 1; $i++ ) {
	my $bit = Milter::SMTPAuth::Utils::ACLEntry::bit_n( $this->_bit_length - $i );
	if ( ! ( $ac->netmask & $bit ) ) {
	    $node->acl_entry( $ac );
	    last;
	}

	if ( $ac->network & $bit ) {
	    if ( ! defined( $node->next_1 ) ) {
		$node->next_1( new Milter::SMTPAuth::Utils::ACLBit( bit => 1 ) );
	    }
	    $node = $node->next_1;
	}
	else {
	    if ( ! defined( $node->next_0 ) ) {
		$node->next_0( new Milter::SMTPAuth::Utils::ACLBit( bit => 0 ) );
	    }
	    $node = $node->next_0;
	}
    }

    return $this;
}


=head2 match( $address )

whether IP address $address is matched or not.
If $address is matched, this method return matched ACLEntry.
If not matched, this method return undef.

=cut

sub match {
    my $this = shift;
    my ( $address ) = @_;

    my $address_binary    = $address->intip();
    my $node              = $this->_top();
    my $matched_acl_entry = undef;
    my $i                 = 0;

    while ( $node ) {
	my $bit = Milter::SMTPAuth::Utils::ACLEntry::bit_n( $this->_bit_length - 1 - $i );

	if ( $node->acl_entry ) {
	    $matched_acl_entry = $node->acl_entry;
	}
	if ( $bit & $address_binary ) {
	    $node = $node->next_1;
	}
	else {
	    $node = $node->next_0;
	}
	$i++;
    }

    return $matched_acl_entry;
}


sub print_bits {
    my $this = shift;
    my ( $num ) = @_;

    for ( my $i = 0 ; $i < $this->_bit_length ; $i++ ) {
	if ( $i % 8 == 0 ) {
	    print STDERR " ";
	}
	my $bit = Milter::SMTPAuth::Utils::ACLEntry::bit_n( $this->_bit_length - $i - 1 );
	printf STDERR "%d", $bit & $num ? 1 : 0;
    }
    print STDERR "\n";
}


package Milter::SMTPAuth::Utils::ACL;

use Moose;
use Data::Dumper;

has '_ipv4_acl' => ( isa     => 'Milter::SMTPAuth::Utils::ACLImp',
		     is      => 'rw',
		     default => sub { new Milter::SMTPAuth::Utils::ACLImp( _bit_length => 32 ) } );

has '_ipv6_acl' => ( isa     => 'Milter::SMTPAuth::Utils::ACLImp',
		     is      => 'rw',
		     default => sub { new Milter::SMTPAuth::Utils::ACLImp( _bit_length => 128 ) } );

=head1 SUBROUTINES/METHODS

=head2

=head2 add( $acl_entry )

add acl_entry.

=cut

sub add {
    my $this = shift;
    my ( $acl_entry ) = @_;

    my $acl = $this->_get_acl( $acl_entry->address() );
    $acl->add( $acl_entry );
}

=head2 match( $address )

whether IP address $address is matched or not.
If $address is matched, this method return matched ACLEntry.
If not matched, this method return undef.

=cut

sub match {
    my $this = shift;
    my ( $str ) = @_;

    my $address = Milter::SMTPAuth::Utils::ACLEntry::check_ip_address( $str );
    my $acl     = $this->_get_acl( $address );
    return $acl->match( $address );
}


sub _get_acl {
    my $this = shift;
    my ( $address ) = @_;

    if ( $address->version() == 4 ) {
	return $this->_ipv4_acl;
    }
    elsif ( $address->version() == 6 ) {
	return $this->_ipv6_acl;
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => sprintf( q{unknown protocol version "%d"}, $address->version ),
	);
    }
}

1;
