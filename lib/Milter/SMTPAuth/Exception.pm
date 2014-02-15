
package Milter::SMTPAuth::Exception;

use Exception::Class (
	'Milter::SMTPAuth::ArgumentError' => {
		fields => [ 'error_message' ],
	},
	'Milter::SMTPAuth::LoggerError' => {
		fields => [ 'error_message' ],
	},
	);

sub Milter::SMTPAuth::ArgumentError::full_message {
    my ( $this ) = @_;
    return $this->error_message;
}

sub Milter::SMTPAuth::LoggerError::full_message {
    my ( $this ) = @_;
    return $this->error_message;
}

1;

