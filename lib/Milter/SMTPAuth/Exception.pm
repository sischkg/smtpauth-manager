
package Milter::SMTPAuth::Exception;

use Exception::Class (
	'Milter::SMTPAuth::SystemError' => {
		fields => [ 'error_message' ],
	},
	'Milter::SMTPAuth::ArgumentError' => {
		fields => [ 'error_message' ],
	},
	'Milter::SMTPAuth::LoggerError' => {
		fields => [ 'error_message' ],
	},
	'Milter::SMTPAuth::CreateGraphError' => {
		fields => [ 'rrd_error', 'error_message' ],
	},
	);

sub Milter::SMTPAuth::SystemError::full_message {
    my ( $this ) = @_;
    return $this->error_message;
}

sub Milter::SMTPAuth::ArgumentError::full_message {
    my ( $this ) = @_;
    return $this->error_message;
}

sub Milter::SMTPAuth::LoggerError::full_message {
    my ( $this ) = @_;
    return $this->error_message;
}

sub Milter::SMTPAuth::CreateGraphError::full_message {
    my ( $this ) = @_;
    return sprintf( '%s(%s)', $this->error_message, $this->rrd_error );
}

1;
