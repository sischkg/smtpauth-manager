# -*- coding: utf-8 mode:cperl -*-

package Milter::SMTPAuth::Logger::File;

use English;
use Readonly;
use Sys::Syslog;
use POSIX qw( strftime );
use IO::File;
use Milter::SMTPAuth::Exception;
use Milter::SMTPAuth::Logger::Outputter;
use Moose;
with 'Milter::SMTPAuth::Logger::Outputter';

has 'filename'       => ( isa => 'Str',                     is => 'ro', required => 1 );
has 'logfile_handle' => ( isa => 'Maybe[IO::File]',         is => 'rw' );
has 'auto_flush'     => ( isa => 'Bool',                    is => 'ro', default => 1 );
has 'current_logfile_date' => ( isa => 'Maybe[Str]',        is => 'rw' );

sub BUILD {
  my $this = shift;

  $this->_create_logfile_handle();
}


=head1 NAME

Milter::SMTPAuth::Logger::File - Auto Rotate Log outputter..

=head1 SYNOPSIS

Quick summary of what the module does.

    use Milter::SMTPAuth::Logger::File;

    my $outputter new Milter::SMTPAuth::Logger::File(
	    filename => '/var/log/smtpauth.maillog'
    );

    $outputter->output( "sent" );
    $outputter->close();

=head1 SUBROUTINES/METHODS

=head2 new

create Outputter instance.

=over 4

=item * filename

log filename

=item * auto_flush (optional)

if true, log file handle is flushed when output method is called.

=back

=cut


sub output {
  my $this = shift;
  my ( $message ) = @_;

  $this->_rotate_logfile();
  OUTPUT_LOOP:
  while ( 1 ) {
	if ( $this->logfile_handle->print( $message ) ) {
	  if ( $this->auto_flush() ) {
		$this->logfile_handle()->flush();
	  }
	  last OUTPUT_LOOP;
	}
	elsif ( $ERRNO == Errno::EINTR ) {
	  next OUTPUT_LOOP;
	}
	else {
	  my $error = sprintf( 'cannot output log "%s"( %s )',
						   $this->filename(),
						   $ERRNO );
	  Milter::SMTPAuth::LoggerError->throw( error_message => $error );
	}
  }
}


sub close {
  my $this = shift;

  $this->logfile_handle->close();
}


sub _create_logfile_handle {
  my $this = shift;

  $this->current_logfile_date( _get_current_date() );
  my $logfile_handle = new IO::File( $this->filename(), O_WRONLY|O_CREAT|O_APPEND );
  if ( ! defined( $logfile_handle ) ) {
	my $error = sprintf( 'cannot open Logger::File logfile "%s"( %s )',
						 $this->filename(),
						 $ERRNO );
	Milter::SMTPAuth::LoggerError->throw( error_message => $error );
  }

  $this->logfile_handle( $logfile_handle );
}


sub _get_current_date {
  return strftime( "%Y%m%d", localtime );
}


sub _rotated_filename {
  my $this = shift;

  return $this->filename . q{.} . $this->current_logfile_date();
}

sub _rotate_logfile {
  my $this = shift;

  my $current_date = _get_current_date();
  if ( $this->current_logfile_date() ne $current_date ) {
	$this->logfile_handle->close();
	printf "rotate %s to %s\n", $this->filename(), $this->_rotated_filename();
	rename( $this->filename(), $this->_rotated_filename() );
	$this->_create_logfile_handle();
  }
}

1;
