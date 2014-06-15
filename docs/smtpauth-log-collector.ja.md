# smtpauth-log-collector

## SYNOPSIS

    smtpauth-log-collector \
        [ --recv_address <socket_address> ] \
        [ --log <log_filename> ] \
        [ --user <user> ] \
        [ --group <group> ] \
        [ --pid_file <pid_filename> ] \
        [ --foreground ]

    smtpauth-log-collector -?|--usage|help

## OPTIONS

*   -?|--usage|help

    使用方法を出力します。

*   --recv_address \<socket_address\>

    smtpauth-log-filterからのログデータを受信するためのSocket Addressを指定します。
    UNIX Domain Socketの場合は、`unix:/var/run/smtpauth/log-collector.sock`のように、
    `unix:<path>`の形式を指定します。 INET(UDP)の場合は、`inet:127.0.0.1:10514`のように
    `inet:<IP address>:<port>`の形式を指定します。 デフォルト値は`unix:/var/run/smtpauth/log-collector.sock`です。

*   --log \<log_filename\>

    メール送受信情報を出力するログファイル名を指定します。デフォルト値は`/var/log/smtpauth/stats.log`です。

*   --user \<user\>

    プロセスの実行ユーザ(EUID)を指定します。デフォルトはsmtpauth-managerです。

*    --group \<group\>

    プロセスの実行グループ(EGID)を指定します。デフォルトはsmtpauth-managerです。

*   --foreground

    smtpauth-log-collectorをforegroundで実行します。デフォルトでは、デーモンとして動作します。

*   --pid_file \<pid_filename\>

    デーモンとして動作するときのPIDファイル名を指定します。デフォルトは`/var/run/smtpauth/log-collector.pid`です。
