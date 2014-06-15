# SYNOPSIS

    smtpauth-filter \
         [--listen_address <milter_address> ] \
         [--logger_address <logger address> ] \
         [--user <user> ] \
         [--group <group> ] \
         [--max_children <children> ] \
         [--max_requests <requests> ] \
         [--pid_file <pid_filename> ] \
         [--foreground]

    smtpauth-filter -?|--usage|help

# OPTIONS

*   -?|--usage|help

    使用方法を出力します。

*   --listen_address \<milter_address\>

    MTAからの接続を受けるMilter用のSocket Addressを指定します。UNIX Domain Socketの場合は、
    `unix:/var/run/smtpauth/filter.sock`のように、`"unix:<path>"`の形式を指定します。
    INET(TCP)の場合は、`inet:127.0.0.1:10025`のように`"inet:<IP address>:<port>"の形式を指定します。
    デフォルト値は`"unix:/var/run/smtpauth/filter.sock"`です。

*   --logger_address \<logger_address\>

    smtpauth-filterは、メール送受信のログデータをsmtpauth-log-collectorへ送信します。
    このオプションで、ログデータの送信先をします。UNIX Domain Socketの場合は、
    `unix:/var/run/smtpauth/log-collector.sock`のように、`"unix:<path>"`の形式を指定します。
    INET(UDP)の場合は、`inet:127.0.0.1:10514`のように`"inet:<IP address>:<port>"の形式を指定します。
    デフォルト値は`"unix:/var/run/smtpauth/log-collector.sock"`です。

*   --user \<user\>

    プロセスの実行ユーザ(EUID)を指定します。デフォルトは`smtpauth-manager`です。

*   --group \<group\>

    プロセスの実行グループ(EUID)を指定します。デフォルトは`smtpauth-manager`です。

*   --max_children \<children\>

    処理を行う子プロセス数を指定します。デフォルトは20です。

*   --max_requests \<requests\>

    ひとつの子プロセスが処理を行うリクエスト数を指定します。この数で指定したリクエストを処理したプロセスは終了し、
    新たに子プロセスが起動されます。デフォルト値は1000です。

*   --foreground

    smtpauth-filterをforegroundで実行します。デフォルトでは、デーモンとして動作します。
 
*   --pid_file \<pid_filename\>

    デーモンとして動作するときのPIDファイル名を指定します。デフォルトは`/var/run/smtpauth/filter.pid`です。
