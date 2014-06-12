# smtpauth-filter

## SYNOPSIS

    smtpauth-filter \
         [-?|--usage|help] \
         [--logger_address <logger address> ] \
         [--user user] \
         [--group group] \
         [--max_children children] \
         [--max_requests requests] \
         [--foreground]

## OPTIONS

*  -?|--usage|help

   Print help message.

*  --logger_address <logger_address>

   Logger socket address, unix domain socket path(  unix:/var/run/smpauth/log.sock ),
   or IP address and port( inet:192.168.0.100:10514 ) of smtpauth-log-collector. 

*  --user <user>

*  --group <group>

*  --max_children <children>

   Preforked process count, defaut is 20.

*  --max_requests <requests>

   Max number of requests per child process. if requests reached max_requests,
   child process is die, and new process is created from parent process. 

*  --foreground

   Smtpauth-filter run foreground mode, is not daemonized. Default mode is daemon mode.
 

