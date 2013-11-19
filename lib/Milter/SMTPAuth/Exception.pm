
package Milter::SMTPAuth::Exception;

use Exception::Class (
	'Milter::SMTPAuth::LoggerError' => {
		fields => [ 'error_message' ],
	},
	);

sub Milter::SMTPAuth::LoggerError::full_message {
	my ( $this ) = @_;

	return $this->error_message;
}

1;



