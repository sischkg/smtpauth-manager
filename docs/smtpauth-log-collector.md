# smtpauth-log-collector

## SYNOPSIS

    smtpauth-log-collector \
        [ -?|--usage|help ] \
        [ --recv_address <socket_address> ] \
        [ --log <log_filename> ] \
        [ --user <user> ] \
        [ --group <group> ] \
        [ --pid_file <pid_filename> ] \
        [ --foreground ]

## OPTION

*   -?|--usage|help

    Print help message.

*  --recv_address \<socket_address\>

   Logger socket address, unix domain socket path(  unix:/var/run/smtpauth/log-collector.sock ),
   or IP address and port( inet:192.168.0.100:10514 ) of smtpauth-log-collector. 
   Default value is "unix:/var/run/smtpauth/log-collector.sock".

*  --log \<log_filename\>

   Statistics log filename. Default value is "/var/log/smtpauth/stats.log".

*  --user \<user\>

   EUID or Username of smtpauth-log-collector process. Default value is "smtpauth-manager".

*  --group \<group\>

   EGID or groupname of smtpauth-log-collector process. Default value is "smtpauth-manager".

*  --foreground

   This option specified, smtpauth-log-collector run forground mode. Default mode is daemon mode.

*  --pid_file \<pid_filename\>

   PID filename. Default value is "/var/run/smtpauth/log-collector.pid".

