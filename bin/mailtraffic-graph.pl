#!/usr/bin/perl
# -*- coding: utf-8; mode:cperl -*-

use strict;
use warnings;
use CGI;
use Milter::SMTPAuth::Logger::RRDTool;

my $cgi = new CGI;
my $period = $cgi->param( 'period' );

my $rrd = new Milter::SMTPAuth::Logger::RRDTool;
my $begin_end = Milter::SMTPAuth::Logger::RRDTool::parse_period( $period );

print $cgi->header( -type => "image/png",
		    -expires => '+60s' );
print $rrd->graph( {
    begin => $begin_end->{begin},
    end   => $begin_end->{end},
} );
