# smtpauth-manager

## SYNOPSIS

    smtpauth-manager \
        [ --basedir <base_dir> ] \
        [ --logdir  <log_dir>  ] \
        [ --foreground ] \
        [ --max_children <children> ] \
        [ --max_request <requests> ]

    smtpauth-manager -?|--usage|help

## OPTIONS

*    -?|--usage|help

     print usage.

*    --basedir \<base_dir\>

     This option specifies the directory which is parent of PID file and UNIX Domain sockets,
     default value is `/var/run/smtpauth`.

*    --logdir \<log_dir\>

     This option specifies the directory of maillog file, defult value is `/var/log/smtpauth`.

*    --foreground

     If this option specifies, smtpauth-manager runs forground mode. Default mode is daemon mode.

*    --max_children \<children\>

     Number of Preforked process, defaut is 20.

*    --max_requests \<requests\>

     Max number of requests per child process. If requests reached max_requests, child process is die, and new process is created from parent process. Default value is 1000.
