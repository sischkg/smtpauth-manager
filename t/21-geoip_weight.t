
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

my $geoip_weight = new Milter::SMTPAuth::Limit::GeoIPWeight;
my $config_data = decode_json( $config_json );
$geoip_weight->load_config( $config_data );

my $message = new Milter::SMTPAuth::Message(
    country => "JP",
);

my $weight = $geoip_weight->get_weight( $message );
ok( 0.9 < $weight && $weight < 1.1, "jp weight is 1.0" );

$message = new Milter::SMTPAuth::Message(
    country => "CN",
);
$weight = $geoip_weight->get_weight( $message );
ok( 9 < $weight && $weight < 11, "CN weight is 10" );

$message = new Milter::SMTPAuth::Message(
    country => "KR",
);
$weight = $geoip_weight->get_weight( $message );
ok( 99 < $weight && $weight < 101, "KR weight is 100" );

done_testing;

