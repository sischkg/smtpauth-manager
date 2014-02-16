# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::RRDTool;

use Moose;
use RRDs;
use Readonly;
use Sys::Syslog;

Readonly::Scalar my $STEP_SECOND => 60;
Readonly::Scalar my $HEARTBEAT_SECOND => 300;
Readonly::Scalar my $DAY   => int( 60 * 60 * 24           / $STEP_SECOND );
Readonly::Scalar my $WEEK  => int( 60 * 60 * 24 * 7       / $STEP_SECOND );
Readonly::Scalar my $MONTH => int( 60 * 60 * 24 * 31      / $STEP_SECOND );
Readonly::Scalar my $YEAR  => int( 60 * 60 * 24 * 365     / $STEP_SECOND );
Readonly::Scalar my $YEAR3 => int( 60 * 60 * 24 * 365 * 3 / $STEP_SECOND );
Readonly::Scalar my $DEFAULT_GRAPH_WIDTH  => 500;
Readonly::Scalar my $DEFAULT_GRAPH_HEIGHT => 200;
Readonly::Scalar my $DEFAULT_PERIOD       => 60 * 60 * 24;



has 'data_directory'     => ( isa => 'Str', is => 'ro', default => '/var/lib/smtpauth/rrd' );
has '_last_updated_time' => ( isa => 'Int', is => 'rw', default => 0 );
has '_received_count'    => ( traits  => [ 'Counter' ],
			      isa     => 'Int',
			      is      => 'rw',
			      default => 0,
			      handles => {
					  '_inc_recv'   => 'inc',
					  '_reset_recv' => 'reset',
				      },
			    );
has '_sent_count'        => ( traits  => [ 'Counter' ],
			      isa     => 'Int',
			      is      => 'rw',
			      default => 0,
			      handles => {
					  '_inc_sent'   => 'inc',
					  '_reset_sent' => 'reset',
					 },
			    );


sub output {
    my $this = shift;
    my ( $message ) = @_;

    my $now = time();
    if ( $this->_last_updated_time() != $now && $this->_last_updated_time() != 0 ) {
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
    my $this = shift;
    my ( $args ) = @_;
    my $width  = $args->{width}  ? $args->{width}  : $DEFAULT_GRAPH_WIDTH;
    my $height = $args->{height} ? $args->{height} : $DEFAULT_GRAPH_HEIGHT;
    my $end    = $args->{end}    ? $args->{end}    : time();
    my $begin  = $args->{begin}  ? $args->{begin}  : $end - $DEFAULT_PERIOD;
    my $title = "mailtrafiic";

    if ( $begin >= $end ) {
	Milter::SMTPAuth::Exception::ArgumentError->throw(
	    error_message => "graph period must be begin < end.",
        );
    }

    my $graph_result = RRDs::graphv( '-',
				     '--start',  $begin,
				     '--end',    $end,
				     '--ttle',   $title,
				     '--width',  $width,
				     '--height', $height,
				     '--vertical-label', 'messages/sec',
				     '--lower-limit',    0,

				     sprintf( 'DEF:recv=%s:recv:AVERAGE', $this->database() ),
				     sprintf( 'DEF:sent=%s:sent:AVERAGE', $this->database() ),
				     sprintf( 'DEF:recv_max=%s:recv:MAX', $this->database() ),
				     sprintf( 'DEF:sent_max=%s:sent:MAX', $this->database() ),

				     strftime( 'COMMENT:"From %Y-%m-%d %H:%M:%d', localtime( $begin ) ) .
				     strftime( ' To %Y-%m-%d %H:%M:%d\\l', localtime( $end ) ),

				     'LINE1:recv#00ff00:recv',
				     'GPRINT:recv:"average: %6.2lf msg/sec',
				     'GPRINT:recv_max:"muximum: %6.2lf msg/sec\\l',

				     'AREA:sent#0000ff:sent',
				     'GPRINT:sent:"average: %6.2lf msg/sec',
				     'GPRINT:sent_max:"maximum: %6.2lf msg/sec\\l',

				     'LINE1:recv_max#00ff00:recv(max):dashes',
				     'LINE1:sent_max#0000ff:sent(max):dashes' );

    if ( my $error = RRDs::error ) {
	Milter::SMTPAuth::CreateGraphError->throw( error_message => 'cannot create RRD graph',
						   rrd_error     => RRDs::error );
    }

    return $graph_result->{image};
}


sub _create_database {
    my $this = shift;

    RRDs::create( $this->database(),
		  '--step',  $STEP_SECOND,
		  "DS:recv:ABSOLUTE:$HEARTBEAT_SECOND:0:U",
		  "DS:sent:ABSOLUTE:$HEARTBEAT_SECOND:0:U",
		  "RRA:AVERAGE:0.5:1:$DAY",
		  "RRA:AVERAGE:0.5:7:$WEEK",
		  "RRA:AVERAGE:0.5:30:$MONTH",
		  "RRA:AVERAGE:0.5:300:$YEAR",
		  "RRA:AVERAGE:0.5:300:$YEAR3",
		  "RRA:MAX:0.5:1:$DAY",
		  "RRA:MAX:0.5:7:$WEEK",
		  "RRA:MAX:0.5:30:$MONTH",
		  "RRA:MAX:0.5:300:$YEAR",
		  "RRA:MAX:0.5:300:$YEAR3" );

    if ( my $error = RRDs::error ) {
	syslog( 'err', 'cannot create RRD file %s(%s).', $this->database, $error );
	Milter::SMTPAuth::CreateGraphError->throw( error_message => 'cannot create RRD file',
						   rrd_error     => RRDs::error );
    }
}


sub _update {
    my $this = shift;

    if ( ! -f $this->database() ) {
	$this->_create_database();
    }

    my $values = sprintf( '%d:%d:%d',
			  $this->_last_updated_time(),
			  $this->_received_count(),
			  $this->_sent_count() );
    RRDs::update( $this->database(),
		  '--template',
		  'recv:sent',
		  $values );
    if ( my $error = RRDs::error ) {
	syslog( 'err', 'cannot update RRD %s(%s).', $this->database, $error );
    }
}


no Moose;
__PACKAGE__->meta->make_immutable;

1;
