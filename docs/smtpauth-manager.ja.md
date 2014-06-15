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

     使用方法を出力します。

*    --basedir \<base_dir\>

     PIDファイルやUNIX Domain Socketを作成するためのディレクトリを指定します。
     デフォルトは`/var/run/smtpauth`です。

*    --logdir \<log_dir\>

     メール送受信のログを保存するためのディレクトリを指定します。
     デフォルトは`/var/log/smtpauth`です。

*    --foreground

     smtpauth-managerをforegroundで実行します。デフォルトでは、デーモンとして動作します

*    --max_children <children>

     処理を行う子プロセス数を指定します。デフォルトは20です。

*    --max_requests <requests>

     ひとつの子プロセスが処理を行うリクエスト数を指定します。この数で指定したリクエストを処理したプロセスは終了し、
     新たに子プロセスが起動されます。デフォルト値は1000です。

## DESCRIPTION

smtpauth-managerは、smtpauth-filterおよびsmtpauth-log-collectorを管理します。

smtpauth-managerは、起動するとsmtpauth-filterとsmtpauth-log-collectorに適切な引数を指定して、起動します。
また終了時は、smtpauth-filterとsmtpauth-log-collectorを停止します。もし、smtpauth-filterとsmtpauth-log-collectorが
以上停止した場合は、自動的に再起動します。

1台のMTAにてmilterを使用する場合は、smtpauth-managerにより簡単にSMTP認証を管理することができます。
