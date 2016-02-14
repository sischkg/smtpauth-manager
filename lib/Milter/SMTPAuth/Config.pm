
package Milter::SMTPAuth::Config;

package Milter::SMTPAuth::Config::Default;

use Readonly;

Readonly::Scalar our $RUN_DIRECTORY     => '/var/run/smtpauth';
Readonly::Scalar our $LOG_DIRECTORY     => '/var/log/smtpauth';
Readonly::Scalar our $MAX_CHILDREN      => 5;
Readonly::Scalar our $MAX_REQUESTS      => 1000;
Readonly::Scalar our $THRESHOLD         => 60;
Readonly::Scalar our $PERIOD            => 120;
Readonly::Scalar our $MAX_MESSAGES      => 10_000;
Readonly::Scalar our $FOREGROUND        => 0;
Readonly::Scalar our $AUTO_REJECT       => 0;
Readonly::Scalar our $ALERT_EMAIL       => 0;
Readonly::Scalar our $ALERT_SENDER      => 'postmaster@localhost.localdomain';
Readonly::Scalar our $ALERT_RECIPIENT   => 'postmaster@localhost.localdomain';
Readonly::Scalar our $ALERT_MAILHOST    => 'localhost';
Readonly::Scalar our $ALERT_PORT        => 25;
Readonly::Scalar our $GEOIP_V4          => '/usr/share/GeoIP/GeoIP.dat';
Readonly::Scalar our $GEOIP_V6          => '/usr/share/GeoIP/GeoIPv6.dat';
Readonly::Scalar our $LISTEN_ADDRESS    => 'unix:/var/run/smtpauth/filter.sock';
Readonly::Scalar our $LOGGER_ADDRESS    => 'unix:/var/run/smtpauth/log-collector.sock';
Readonly::Scalar our $USER              => 'smtpauth-manager';
Readonly::Scalar our $GROUP             => 'smtpauth-manager';
Readonly::Scalar our $FILTER_PID        => "$RUN_DIRECTORY/filter.pid";
Readonly::Scalar our $LOG_COLLECTOR_PID => "$RUN_DIRECTORY/log-collector.pid";
Readonly::Scalar our $STATISTICS_LOG    => "$LOG_DIRECTORY/stats.log";
Readonly::Scalar our $WEIGHT_CONFIG     => '/etc/smtpauth/weight.json';

package Milter::SMTPAuth::Config::ManagerConfig;

use Moose;
use Moose::Util::TypeConstraints;
with 'MooseX::Getopt';

foreach my $dir ( qw( RunDirectory LogDirectory ) ) {
    subtype "ManagerOption::$dir", as 'Str', where { -d $_ }, message {qq{$dir directory "$_" must exist.}};
}

foreach my $value ( qw( MaxChildren MaxRequests Threshold Period MaxMessages) ) {
    subtype "ManagerOption::$value", as 'Int', where { $_ >= 0 }, message {"$value must be plus integer."};
}

has 'rundir' =>
    ( isa => 'ManagerOption::RunDirectory', is => 'ro', default => $Milter::SMTPAuth::Config::Default::RUN_DIRECTORY );
has 'logdir' =>
    ( isa => 'ManagerOption::LogDirectory', is => 'ro', default => $Milter::SMTPAuth::Config::Default::LOG_DIRECTORY );
has 'max_children' =>
    ( isa => 'ManagerOption::MaxChildren', is => 'ro', default => $Milter::SMTPAuth::Config::Default::MAX_CHILDREN );
has 'max_requests' =>
    ( isa => 'ManagerOption::MaxRequests', is => 'ro', default => $Milter::SMTPAuth::Config::Default::MAX_REQUESTS );
has 'threshold' =>
    ( isa => 'ManagerOption::Threshold', is => 'ro', default => $Milter::SMTPAuth::Config::Default::THRESHOLD );
has 'period' => ( isa => 'ManagerOption::Period', is => 'ro', default => $Milter::SMTPAuth::Config::Default::PERIOD );
has 'max_messages' =>
    ( isa => 'ManagerOption::MaxMessages', is => 'ro', default => $Milter::SMTPAuth::Config::Default::MAX_MESSAGES );
has 'foreground'     => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::FOREGROUND );
has 'auto_reject'    => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::AUTO_REJECT );
has 'alert_email'    => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_EMAIL );
has 'alert_mailhost' => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_MAILHOST );
has 'alert_port'     => ( isa => 'Int',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_PORT );
has 'alert_sender'   => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_SENDER );
has 'alert_recipient' =>
    ( isa => 'ArrayRef[Str]', is => 'ro', default => sub { [ $Milter::SMTPAuth::Config::Default::ALERT_RECIPIENT ] } );
has 'weight'   => ( isa => 'Maybe[Str]', is => 'ro', default => $Milter::SMTPAuth::Config::Default::WEIGHT_CONFIG );
has 'geoip_v4' => ( isa => 'Str',        is => 'ro', default => $Milter::SMTPAuth::Config::Default::GEOIP_V4 );
has 'geoip_v6' => ( isa => 'Str',        is => 'ro', default => $Milter::SMTPAuth::Config::Default::GEOIP_V6 );

no Moose;
__PACKAGE__->meta->make_immutable;

package Milter::SMTPAuth::Config::FilterConfig;

use Moose;
use Moose::Util::TypeConstraints;
with 'MooseX::Getopt';

foreach my $value ( qw( MaxChildren MaxRequests ) ) {
    subtype "FilterOption::$value", as 'Int', where { $_ >= 0 }, message {"$value must be plus integer."};
}

has 'listen_address' => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::LISTEN_ADDRESS );
has 'logger_address' => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::LOGGER_ADDRESS );
has 'user'           => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::USER );
has 'group'          => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::GROUP );
has 'foreground'     => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::FOREGROUND );
has 'pid_file'       => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::FILTER_PID );
has 'max_children' =>
    ( isa => 'ManagerOption::MaxChildren', is => 'ro', default => $Milter::SMTPAuth::Config::Default::MAX_CHILDREN );
has 'max_requests' =>
    ( isa => 'ManagerOption::MaxRequests', is => 'ro', default => $Milter::SMTPAuth::Config::Default::MAX_REQUESTS );

package Milter::SMTPAuth::Config::LogCollectorConfig;

use Moose;
use Moose::Util::TypeConstraints;
with 'MooseX::Getopt';

foreach my $value ( qw( Threshold Period MaxMessages ) ) {
    subtype "LogCollectorOption::$value", as 'Int', where { $_ >= 0 }, message {"$value must be plus integer."};
}

has 'recv_address'   => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::LOGGER_ADDRESS );
has 'log'            => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::STATISTICS_LOG );
has 'user'           => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::USER );
has 'group'          => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::GROUP );
has 'foreground'     => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::FOREGROUND );
has 'pid_file'       => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::LOG_COLLECTOR_PID );
has 'auto_reject'    => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::AUTO_REJECT );
has 'alert_email'    => ( isa => 'Bool', is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_EMAIL );
has 'alert_mailhost' => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_MAILHOST );
has 'alert_port'     => ( isa => 'Int',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_PORT );
has 'alert_sender'   => ( isa => 'Str',  is => 'ro', default => $Milter::SMTPAuth::Config::Default::ALERT_SENDER );
has 'alert_recipient' =>
    ( isa => 'ArrayRef[Str]', is => 'ro', default => sub { [ $Milter::SMTPAuth::Config::Default::ALERT_RECIPIENT ] } );
has 'threshold' =>
    ( isa => 'LogCollectorOption::Threshold', is => 'ro', default => $Milter::SMTPAuth::Config::Default::THRESHOLD );
has 'period' =>
    ( isa => 'LogCollectorOption::Period', is => 'ro', default => $Milter::SMTPAuth::Config::Default::PERIOD );
has 'max_messages' => (
    isa     => 'LogCollectorOption::MaxMessages',
    is      => 'ro',
    default => $Milter::SMTPAuth::Config::Default::MAX_MESSAGES );
has 'weight'   => ( isa => 'Str', is => 'ro', default => $Milter::SMTPAuth::Config::Default::WEIGHT_CONFIG );
has 'geoip_v4' => ( isa => 'Str', is => 'ro', default => $Milter::SMTPAuth::Config::Default::GEOIP_V4 );
has 'geoip_v6' => ( isa => 'Str', is => 'ro', default => $Milter::SMTPAuth::Config::Default::GEOIP_V6 );

no Moose;
__PACKAGE__->meta->make_immutable;

1;

