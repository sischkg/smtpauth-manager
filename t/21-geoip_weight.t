
use strict;
use warnings;
use Test::More;
use JSON;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::Limit;
use Milter::SMTPAuth::Limit::GeoIPWeight;
use Readonly;
use Test::MockObject;


my $geoip = new Test::MockObject;
$geoip->fake_module(
    'Milter::SMTPAuth::Utils::GeoIP',
    get_country_code => sub { return 'JP' },
);
$geoip->fake_new(    'Milter::SMTPAuth::Utils::GeoIP' );
$geoip->set_series( 'get_country_code', "JP", "CN", "KR" );

my $config_json =<<END_CONFIG;
{
    "country": [
        {
	    "code": "CN",
	    "weight": 10
        },
        {
	    "code": "KR",
	    "weight": 100
        }
    ]
}

END_CONFIG

my $geoip_weight = new Milter::SMTPAuth::Limit::GeoIPWeight(
    geoip => new Milter::SMTPAuth::Utils::GeoIP,
);
my $config_data = decode_json( $config_json );
$geoip_weight->load_config( $config_data );

my $message = new Milter::SMTPAuth::Message(
    client_address => "127.0.0.1",
);

my $weight = $geoip_weight->get_weight( $message );
ok( 0.9 < $weight && $weight < 1.1, "jp weight is 1.0" );

$weight = $geoip_weight->get_weight( $message );
ok( 9 < $weight && $weight < 11, "CN weight is 10" );

$weight = $geoip_weight->get_weight( $message );
ok( 99 < $weight && $weight < 101, "KR weight is 100" );

done_testing;

