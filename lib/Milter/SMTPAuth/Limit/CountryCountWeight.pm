
package Milter::SMTPAuth::Limit::CountryCountWeight;

use Moose;
use Sys::Syslog;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Limit::Role;

with 'Milter::SMTPAuth::Limit::Role';

has 'ratio' => ( isa => 'Num', is => 'rw', default => 1 );

sub load_config {
    my $this = shift;
    my ( $config_data ) = @_;

    if (   !exists( $config_data->{country_count} )
        && !exists( $config_data->{country_count}->{ratio} ) ) {
        return;
    }

    $this->ratio( $config_data->{country_count}->{ratio} );
}

sub get_weight {
    my $this = shift;
    my ( $messages ) = @_;

    my %countries = ();
    foreach my $message ( @{$messages} ) {
        $countries{ $message->country() } = 1;
    }
    delete $countries{undef};

    my $count = keys( %countries );
    return $this->ratio()**( $count - 1 );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
