# smtpauth-filter

## SYNOPSIS

    # smtpauth-filter \
         [-?|--usage|help] \
         [--listen_address <milter_address> ] \
         [--logger_address <logger_address> ] \
         [--user <user> ] \
         [--group <group> ] \
         [--max_children <children> ] \
         [--max_requests <requests> ] \
         [--pid_file <pid_filename> ] \
         [--foreground]

## OPTIONS

*  -?|--usage|help

   Print help message.

*  --listen_address \<milter_address\>

   Milter socket address, unix domain socket path( unix:/var/run/smpauth/filter.sock ),
   or IP address and port( inet:192.168.0.100:10025 ). Default value is "unix:/var/run/smpauth/filter.sock".

*  --logger_address \<logger_address\>

   Logger socket address, unix domain socket path( unix:/var/run/smpauth/log-collector.sock ),
   or IP address and port( inet:192.168.0.100:10514 ) of smtpauth-log-collector. 
   Default value is "unix:/var/run/smpauth/log-collector.sock".

*  --user \<user\>

   EUID of process, default user is smtpauth-manager.

*  --group \<group\>

   EGID of process, default user is smtpauth-manager.

*  --max_children \<children\>

   Preforked process count, defaut is 20.

*  --max_requests \<requests\>

   Max number of requests per child process. if requests reached max_requests,
   child process is die, and new process is created from parent process. 
   Default value is 1000.

*  --foreground

   Smtpauth-filter run foreground mode, is not daemonized. Default mode is daemon mode.
 
*  --pid_file \<pid_filename\>

   PID filename. Default value is "/var/run/smtpauth/filter.pid".

