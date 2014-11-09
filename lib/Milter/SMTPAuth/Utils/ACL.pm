
package Milter::SMTPAuth::Utils::ACLEntry;

use Moose;
use Scalar::Util qw(looks_like_number);
use Milter::SMTPAuth::Exception;
use Data::Dumper;

has 'network' => ( isa => 'Int',        is => 'ro', required => 1 );
has 'netmask' => ( isa => 'Int',        is => 'ro', required => 1 );
has 'name'    => ( isa => 'Maybe[Str]', is => 'ro' );
has 'value'   => ( isa => 'Any',        is => 'rw' );


=head1 NAME

Milter::SMTPAuth::Utils::ACLEntry - Network ACL entry.

=head1 SYNOPSIS

Quick summary of what the module does.

    # log server
    use Milter::SMTPAuth::Utils::ACL;

    my $my_network = new Milter::SMTPAuth::Utils::ACLEntry(
        network    => '172.16.10.0',
        bit_length => 24,
        name       => 'my network',
        value      => 1,
    );

    $my_network->network; # return 172 * (2**24) + 16 * (2**16) + 10 * (2**8) + 0;
    $my_network->netmask; # return 2 ** 32 - 2**(32 - 24 ) - 1

=head1 SUBROUTINES/METHODS

=head2 new

=over 4

=item * network

Network address like 172.16.12.0.

=item * bit_length

Bit length.

=item * name

Network name.

=item * value

=back

=head2 check_ip_address( $str )

check $str is IP address format, and return binary format of network address $str.

=cut

sub check_ip_address {
    my ( $addr ) = @_;

    if ( $addr =~ /\A(\d+)\.(\d+)\.(\d+)\.(\d+)\z/ ) {
	return $1 * (2**24) + $2 * (2**16) + $3 * (2**8) + $4;
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => qq{Invalide network address "$addr"},
	);
    }
}

=head2 check_bit_lenght( $str )

check $str is bit length format(positive number and <= 32), and return binary format of network mask.

=cut

sub check_bit_length {
    my ( $bit_length ) = @_;

    if ( $bit_length =~ /\A\d+\z/ ) {
	if ( $bit_length > 32 ) {
	    Milter::SMTPAuth::ArgumentError->throw(
		error_message => qq{Invalide bit length "$bit_length"},
	    );
	}
	return 2 ** 32 - 2 ** ( 32 - $bit_length );
    }
    else {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => qq{Invalide bit length "$bit_length"},
	);
    }
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    my $args = $class->$orig( @_ );
    my $network = check_ip_address( $args->{network} );
    my $netmask = check_bit_length( $args->{bit_length} );

    if ( ( $network & ~$netmask ) != 0 ) {
	Milter::SMTPAuth::ArgumentError->throw(
	    error_message => sprintf( q{Invalid network address/bit length "%s/%s"},
				      $args->{network},
				      $args->{bit_length} ),
	);
    }

    return {
	network => $network,
	netmask => $netmask,
	name    => $args->{name},
	value   => $args->{value},
    };
};



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
        network    => '172.16.10.0',
        bit_length => 24,
        name       => 'my network',
        value      => 1,
    );

    my $group_network = new Milter::SMTPAuth::Utils::ACLEntry(
        network    => '172.16.10.0',
        bit_length => 16,
        name       => 'group network',
        value      => 2,
    );

    my $my_host = new Milter::SMTPAuth::Utils::ACLEntry(
        network    => '172.16.10.101',
        bit_length => 32,
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

package Milter::SMTPAuth::Utils::ACL;

use Moose;
use Data::Dumper;

has '_top' => ( isa => 'Milter::SMTPAuth::Utils::ACLBit',
		is  => 'ro',
		default => sub { new Milter::SMTPAuth::Utils::ACLBit( bit => 0 ) } );


=head1 SUBROUTINES/METHODS

=head2 new



=head2 add( $acl_entry )

add acl_entry.

=cut

sub add {
    my $this = shift;
    my ( $ac ) = @_;

    my $node = $this->_top();
    for ( my $i = 0 ; $i <= 32 ; $i++ ) {
	my $bit = shift_bit_1( 31 - $i );
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
}


=head2 match( $address )

whether IP address $address is matched or not.
If $address is matched, this method return matched ACLEntry.
If not matched, this method return undef.

=cut

sub match {
    my $this = shift;
    my ( $address ) = @_;

    my $address_binary    = Milter::SMTPAuth::Utils::ACLEntry::check_ip_address( $address );
    my $node              = $this->_top();
    my $matched_acl_entry = undef;
    my $i                 = 0;

    while ( $node ) {
	my $bit = shift_bit_1( 31 - $i );

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
    my ( $num ) = @_;

    for ( my $i = 0 ; $i < 32 ; $i++ ) {
	if ( $i % 8 == 0 ) {
	    print STDERR " ";
	}
	my $bit = 2 ** ( 31 - $i );
	printf STDERR "%d", $bit & $num ? 1 : 0;
    }
    print STDERR "\n";
}

sub shift_bit_1 {
    my ( $digit ) = @_;
    if ( $digit >= 0 ) {
	return 1 << $digit;
    }
    else {
	return 0;
    }
}

1;
