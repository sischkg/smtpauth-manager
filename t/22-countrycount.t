
use strict;
use warnings;
use Test::More;
use JSON;
use Milter::SMTPAuth::Utils;
use Milter::SMTPAuth::Message;
use Milter::SMTPAuth::Limit;
use Milter::SMTPAuth::Limit::CountryCountWeight;
use Readonly;
use Test::MockObject;

my $config_json = <<END_CONFIG;
{
    "country_count":
        {
	    "ratio": 2
        }
}

END_CONFIG

my $count_weight = new Milter::SMTPAuth::Limit::CountryCountWeight;
my $config_data  = decode_json( $config_json );
$count_weight->load_config( $config_data );

my $messages = [
    new Milter::SMTPAuth::Message( country => "JP", ),
    new Milter::SMTPAuth::Message( country => "JP", ),
    new Milter::SMTPAuth::Message( country => "JP", ), ];

my $weight = $count_weight->get_weight( $messages );
ok( 0.9 < $weight && $weight < 1.1, "weight is 1.0" );

$messages = [
    new Milter::SMTPAuth::Message( country => "JP", ),
    new Milter::SMTPAuth::Message( country => "JP", ),
    new Milter::SMTPAuth::Message( country => "CN", ), ];

$weight = $count_weight->get_weight( $messages );
ok( 1.9 < $weight && $weight < 2.1, "weight is 2.0" );

$messages = [
    new Milter::SMTPAuth::Message( country => "JP", ),
    new Milter::SMTPAuth::Message( country => "KR", ),
    new Milter::SMTPAuth::Message( country => "CN", ), ];

$weight = $count_weight->get_weight( $messages );
ok( 3.9 < $weight && $weight < 4.1, "weight is 4.0" );

done_testing;

