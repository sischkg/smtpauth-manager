# smtpauth-manager

smtpauth-managerは、SMTP認証のIDによるメール送信を拒否するためのアプリケーションです。
このアプリケーションはMilterで、SendmailやPostfixなどのMTAとともに使用します。
設定ファイルにSMTP認証のIDを記載すると、そのIDからのメール送信を拒否するようになります。
また、スパム送信などによる大量メール送信を検知するために、メール送信のログを
ファイルへする機能もあります。

## 必要なソフトウェア

* Perl 5.14以上
* Perl Module
    * Sendmail-PMilter 1.00以上
    * Readonly
    * Time::Piece
    * Moose
    * MooseX::Getopt
    * MooseX::Daemonize
    * Exception::Class
    * Email::Address
    * Authen::SASL
    * RRDs

## インストール方法

    $ perl Makefile.PL
    $ make
    $ su
    # make install

## 環境別インストール及び設定

### CentOS 6.4 + postfixの場合

EPELリポジトリをyumへ追加します。

x86_64

    # rpm -Uhv http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

i386

    # rpm -Uhv http://dl.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm

smtpauth-managerに必要なソフトウェアをインストールします。

    # yum -y install \
        git \
        perl \
        perl-Readonly \
        perl-Time-Piece \
        perl-Moose \
        perl-MooseX-Getopt \
        perl-MooseX-Daemonize \
        perl-Exception-Class \
        perl-Email-Address \
        perl-Authen-SASL \
        perl-CGI \
        rrdtool-perl \
        perl-Sendmail-PMilter

smtpauth-managerをインストールします。

    $ git clone https://github.com/sischkg/smtpauth-manager.git
    $ cd smtpauth-manager
    $ perl Makefile.PL
    $ make
    $ su
    # make install

smtpauth-manager用のユーザ・グループを作成します。

    # groupadd smtpauth-manager
    # useradd -g smtpauth-manager -d /noexistent -s /bin/false smtpauth-manager
    # gpasswd -a postfix smtpauth-manager

拒否設定用のファイルを作成します。ファイルには、一行ごとに拒否対象のSMTP認証のIDを記載します。

    # mkdir /etc/smtpauth-filter/
    # vi /etc/smtpauth-filter/reject_ids.txt

    spammer
    virus
    evil

ログ保存先のディレクトリを作成します。

    # mkdir -p /var/log/smtpauth /var/lib/smtpauth/rrd
    # chown smtpauth-manager:smtpauth-manager /var/log/smtpauth /var/lib/smtpauth/rrd

起動スクリプトを作成します。

    # cp data/centos6/smtpauth-manager /etc/init.d
    # chmod 744 /etc/init.d/smtpauth-manager
    # chkconfig --add smtpauth-manager

サービスを起動します。

    # service smtpauth-manager
    # chkconfig smtpauth-manager on

PostfixへMilterの設定を追加します。

    # vi /etc/postfix/main.cf

    smtpd_milters = unix:/var/run/smtpauth/filter.sock

    # postfix reload

## ログファイル

SMTPクライアントがメッセージを1通送信すると、smtpauth-managerはファイル(default: /var/log/smtpauth/stats.log)
へログを出力します。

ログのフォーマットは、以下のとおりです。

    client:<client 1><tab>connect_time:<connect_time 1><tab>sender:<sender 1><tab>eom_time:<eom_time><tab>recipient:<recipient 1>
    client:<client 2><tab>connect_time:<connect_time 2><tab>sender:<sender 2><tab>eom_time:<eom_time><tab>recipient:<recipient 2.1><tab>recipient:<recipient 2.2>
    sender:<sender 3><tab>client:<client 3><tab>eom_time:<eom_time><tab>recipient:<recipient 3><tab>connect_time:<connect_time 3>
    ...

    <clinet>: SMTPクライアントのIP address。
    <auth_id>: SMTP認証のID。
    <sender>: エンベロープの送信者メールアドレス( MAIL From: )。
    <recipient>: エンベロープの宛先メールアドレス( RCPT To: )。
    <connect_time>: SMTPクライアントがMTAに接続した時刻。フォーマットは"YYYY-MM-DD HH:MM:SS"。
    <eom_time>: MTAがSMTPクライアントからメッセージを受信した時刻( End of message ".\r\n" )。フォーマットは"YYYY-MM-DD HH:MM:SS"。
    <tab>: TAB ("\t")。

このログファイルのフォーマットは、LTSV(<http://ltsv.org/>)とほぼ同じです。ただし、同じ行の中に同じラベルが複数個存在する場合があります。
具体的には、メッセージの宛先が複数存在する場合、ラベル"recipient"も複数存在します。

ログファイルは毎日ログローテーションします。ログローテート後のファイル名は"/var/log/smtpauth/stats.log.YYYYMMDD"です。
 
## RRD

受信したメッセージ数と、送信したメッセージ数(Recipients数)をRRDファイルへ保存します。
RRDファイル名: /var/lib/smtpauth/rrd/stats.rrd

### Graph

上記のRRDファイルからメールトラフィックのグラフを表示することができます。
Apache httpdをインストールします。

    # yum -y install httpd

HTMLファイル及びCGIをコピーします。

    # cp -r data/public /var/www/html/smtpauth

httpdの設定ファイルをコピーします。

    # cp data/centos6/smtpauth-manager.conf /etc/httpd/conf.d/

httpdを起動します。

    # service httpd start
    # chkconfig httpd on

以下のURLでメールトラフィックのグラフを参照することができます。

    http://<server>/smtpauth/


