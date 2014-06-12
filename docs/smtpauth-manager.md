
# smtpauth-manager

## SYNOPSIS

     # smtpauth-manager \
           [ --basedir <base_directory> ] \
           [ --logdir  <log_directory>  ] \
           [ --foreground ] \
           [ --max_children <max_children> ] \
           [ --max_requests <max_requests> ]

## OPTIONS

*  --basedir \<base_directory\>

   This specifies the directory for pid file, and unix domain sockets of milter and logger process.
   Default value is "/var/run/smtpauth".

*  --logdir \<log_directory\>

   Log file is stored under the \<log_directory\>. Default directory is "/var/log/smtpauth".

*  --foreground

   If this option is specified, smtpauth-manager runs foreground mode, not daemon.
   Default mode is daemon.

*  --max_children \<children\>

   This option specifies the number of preforked child processes. Default value is 20. 

*  --max_requests \<requests\>

   This option specifies the number of requests performed by a child process.
   If requests reached max_requests, child process is die, and new process is created by parent process.

