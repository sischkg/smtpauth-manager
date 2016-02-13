# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::RRDToolStorable;

use Moose::Role;
requires 'output';

package Milter::SMTPAuth::Logger::RRDTool;

use Moose;
use RRDs;
use Readonly;
use Sys::Syslog;
use POSIX qw(strftime);
use Milter::SMTPAuth::Exception;

with 'Milter::SMTPAuth::Logger::RRDToolStorable';

Readonly::Scalar my $STEP_SECOND          => 60;
Readonly::Scalar my $HEARTBEAT_SECOND     => 300;
Readonly::Scalar my $DAY                  => int( 60 * 60 * 24 / $STEP_SECOND );
Readonly::Scalar my $WEEK                 => int( 60 * 60 * 24 * 7 / $STEP_SECOND );
Readonly::Scalar my $MONTH                => int( 60 * 60 * 24 * 31 / $STEP_SECOND );
Readonly::Scalar my $YEAR                 => int( 60 * 60 * 24 * 365 / $STEP_SECOND );
Readonly::Scalar my $YEAR3                => int( 60 * 60 * 24 * 365 * 3 / $STEP_SECOND );
Readonly::Scalar my $DEFAULT_GRAPH_WIDTH  => 500;
Readonly::Scalar my $DEFAULT_GRAPH_HEIGHT => 200;
Readonly::Scalar my $DEFAULT_PERIOD       => 60 * 60 * 24;

has 'data_directory'     => ( isa => 'Str', is => 'ro', default => '/var/lib/smtpauth/rrd' );
has '_last_updated_time' => ( isa => 'Int', is => 'rw', default => 0 );
has '_received_count'    => (
    traits  => [ 'Counter' ],
    isa     => 'Int',
    is      => 'rw',
    default => 0,
    handles => {
        '_inc_recv'   => 'inc',
        '_reset_recv' => 'reset',
    }, );
has '_sent_count' => (
    traits  => [ 'Counter' ],
    isa     => 'Int',
    is      => 'rw',
    default => 0,
    handles => {
        '_inc_sent'   => 'inc',
        '_reset_sent' => 'reset',
    }, );

sub output {
    my $this = shift;
    my ( $message ) = @_;

    my $now = time();
    if (   $this->_last_updated_time() != $now
        && $this->_last_updated_time() != 0 ) {
        $this->_update();
        $this->_reset_recv();
        $this->_reset_sent();
    }
    $this->_last_updated_time( $now );

    $this->_inc_recv();
    $this->_inc_sent( $message->recipients_count() );
}

sub database {
    my $this = shift;
    return sprintf( "%s/stats.rrd", $this->data_directory );
}

sub graph {
    my $this     = shift;
    my ( $args ) = @_;
    my $width    = $args->{width} ? $args->{width} : $DEFAULT_GRAPH_WIDTH;
    my $height   = $args->{height} ? $args->{height} : $DEFAULT_GRAPH_HEIGHT;
    my $end      = $args->{end} ? $args->{end} : time();
    my $begin    = $args->{begin} ? $args->{begin} : $end - $DEFAULT_PERIOD;
    my $title    = "mailtrafiic";

    if ( $begin >= $end ) {
        Milter::SMTPAuth::Exception::ArgumentError->throw( error_message => "graph period must be begin < end.", );
    }

    my $graph_result = RRDs::graphv(
        '-',
        '--imgformat',      'PNG',
        '--start',          $begin,
        '--end',            $end,
        '--title',          $title,
        '--width',          $width,
        '--height',         $height,
        '--vertical-label', 'messages/sec',
        '--lower-limit',    0,

        sprintf( 'DEF:recv=%s:recv:AVERAGE',   $this->database() ),
        sprintf( 'DEF:sent=%s:sent:AVERAGE',   $this->database() ),
        sprintf( 'DEF:recv_max=%s:recv:MAX',   $this->database() ),
        sprintf( 'DEF:sent_max=%s:sent:MAX',   $this->database() ),
        sprintf( 'DEF:recv_last=%s:recv:LAST', $this->database() ),
        sprintf( 'DEF:sent_last=%s:sent:LAST', $this->database() ),

        'VDEF:v_recv_avg=recv,AVERAGE',
        'VDEF:v_recv_max=recv_max,MAXIMUM',
        'VDEF:v_recv_last=recv_last,LAST',
        'VDEF:v_sent_avg=sent,AVERAGE',
        'VDEF:v_sent_max=sent_max,MAXIMUM',
        'VDEF:v_sent_last=sent_last,LAST',

        strftime( 'COMMENT:From %Y-%m-%d %H\\:%M\\:%d', localtime( $begin ) )
            . strftime( ' To %Y-%m-%d %H\\:%M\\:%d\\c', localtime( $end ) ),

        'LINE1:recv#00ff00:recv',
        'GPRINT:v_recv_avg:Average\: %6.2lf',
        'GPRINT:v_recv_max:Maximum\: %6.2lf',
        'GPRINT:v_recv_last:Last\: %6.2lf\\c',

        'AREA:sent#0000ff:sent',
        'GPRINT:v_sent_avg:Average\: %6.2lf',
        'GPRINT:v_sent_max:Maximum\: %6.2lf',
        'GPRINT:v_sent_last:Last\: %6.2lf\\c',

        'LINE1:recv_max#00ff00:recv(max):dashes',
        'COMMENT:                                         \\c',
        'LINE1:sent_max#0000ff:sent(max):dashes',
        'COMMENT:                                         \\c', );

    if ( my $error = RRDs::error ) {
        Milter::SMTPAuth::CreateGraphError->throw(
            error_message => 'cannot create RRD graph',
            rrd_error     => RRDs::error );
    }

    return $graph_result->{image};
}

sub _create_database {
    my $this = shift;

    RRDs::create(
        $this->database(),                        '--step',
        $STEP_SECOND,                             "DS:recv:ABSOLUTE:$HEARTBEAT_SECOND:0:U",
        "DS:sent:ABSOLUTE:$HEARTBEAT_SECOND:0:U", "RRA:AVERAGE:0.5:1:$DAY",
        "RRA:AVERAGE:0.5:7:$WEEK",                "RRA:AVERAGE:0.5:30:$MONTH",
        "RRA:AVERAGE:0.5:300:$YEAR",              "RRA:AVERAGE:0.5:900:$YEAR3",
        "RRA:MAX:0.5:1:$DAY",                     "RRA:MAX:0.5:7:$WEEK",
        "RRA:MAX:0.5:30:$MONTH",                  "RRA:MAX:0.5:300:$YEAR",
        "RRA:MAX:0.5:900:$YEAR3",                 "RRA:LAST:0.5:1:$DAY",
        "RRA:LAST:0.5:7:$WEEK",                   "RRA:LAST:0.5:30:$MONTH",
        "RRA:LAST:0.5:300:$YEAR",                 "RRA:LAST:0.5:900:$YEAR3" );

    if ( my $error = RRDs::error ) {
        syslog( 'err', 'cannot create RRD file %s(%s).', $this->database, $error );
        Milter::SMTPAuth::CreateGraphError->throw(
            error_message => 'cannot create RRD file',
            rrd_error     => RRDs::error );
    }
}

sub _update {
    my $this = shift;

    if ( !-f $this->database() ) {
        $this->_create_database();
    }

    my $values = sprintf( '%d:%d:%d', $this->_last_updated_time(), $this->_received_count(), $this->_sent_count() );
    RRDs::update( $this->database(), '--template', 'recv:sent', $values );
    if ( my $error = RRDs::error ) {
        syslog( 'err', 'cannot update RRD %s(%s).', $this->database, $error );
    }

    my $now = time();
    for ( my $t = $this->_last_updated_time() + 1; $t < $now; $t++ ) {
        RRDs::update( $this->database(), '--template', 'recv:sent', "$t:0:0" );
        if ( my $error = RRDs::error ) {
            syslog( 'err', 'cannot update RRD %s while filling 0(%s).', $this->database, $error );
        }
    }
}

sub parse_period {
    my ( $period ) = @_;
    if ( !defined( $period )
        || ( $period ne 'week' && $period ne 'month' && $period ne 'year' ) ) {
        $period = 'day';
    }

    my $end   = time();
    my $begin = time() - 24 * 60 * 60;
    if ( $period eq 'week' ) {
        $begin = $end - 7 * 24 * 60 * 60;
    }
    elsif ( $period eq 'month' ) {
        $begin = $end - 31 * 24 * 60 * 60;
    }
    elsif ( $period eq 'year' ) {
        $begin = $end - 365 * 24 * 60 * 60;
    }

    return { begin => $begin, end => $end };
}

no Moose;
__PACKAGE__->meta->make_immutable;

package Milter::SMTPAuth::Logger::NoRRDTool;

use Moose;
with 'Milter::SMTPAuth::Logger::RRDToolStorable';

sub output {

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
