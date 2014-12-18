use 5.10.1;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Milter::SMTPAuth',
    AUTHOR              => q{Toshifumi Sakaguchi <sischkg@gmail.com>},
    VERSION_FROM        => 'lib/Milter/SMTPAuth.pm',
    ABSTRACT_FROM       => 'lib/Milter/SMTPAuth.pm',
    EXE_FILES           => [
        'bin/smtpauth-log-collector',
        'bin/smtpauth-logger',
        'bin/smtpauth-test',
        'bin/smtpauth-filter',
        'bin/smtpauth-manager',
        'bin/mailtraffic-graph.pl',
    ],
    PREREQ_PM => {
        'Test::More'         => 0,
        'Time::Piece'        => '1.15',
	'version'            => 0,
        'Readonly'           => 0,
        'Exception::Class'   => 0,
        'Moose'              => 0,
        'MooseX::Getopt'     => 0,
        'MooseX::Daemonize'  => 0,
        'Sendmail::PMilter'  => 0,
        'Email::Address'     => '1.889',
        'Authen::SASL'       => 0,
	'RRDs'               => 0,
	'Net::IP'            => 0,
        'Net::INET6Glue'     => 0,
        'Geo::IP'            => 0,
	'Test::MockObject'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Milter-SMTPAuth-*' },
);
