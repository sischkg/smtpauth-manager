# smtpauth-manager

smtpauth-managerは、SMTP認証によるスパムメール送信(サブミッションスパム)を拒否するためのアプリケーションです。
このアプリケーションはMilterで、SendmailやPostfixなどのMTAとともに使用します。設定ファイルにSMTP認証のIDを記載すると、
MTAはそのIDからのメール送信を拒否するようになります。

また、スパム送信などによる大量メール送信を検知するために、メール送信のログをファイルへ出力する機能もあります。

## 必要なソフトウェア

* Perl >= 5.14
* Perl Mudules
   + Sendmail-PMilter >= 1.00
   + Readonly
   + Time::Piece
   + Geo::IP
   + Moose
   + MooseX::Getopt
   + MooseX::Daemonize
   + Exception::Class
   + Email::Address
   + Email::Simple
   + Email::Date::Format
   + Email::Send
   + Authen::SASL
   + RRDs
   + Net::INET6Glue
   + Test::MockObject(for make test)* Perl >= 5.14

## 環境別インストール及び設定

### CentOS 6.7 + postfixの場合

EPELリポジトリをyumへ追加します。

    # yum install epel-release

smtpauth-managerに必要なソフトウェアをインストールします。

    # yum -y install \
        perl \
        perl-Moose \
        perl-MooseX-Getopt \
        perl-MooseX-Types \
        perl-MooseX-Types-Path-Class \
        perl-MooseX-Daemonize \
        perl-Readonly \
        perl-Exception-Class \
        rrdtool-perl \
        perl-Authen-SASL \
        perl-Email-Address \
        perl-Email-Simple \
        perl-Email-Date-Format \
        perl-Email-Send \
        perl-Time-Piece \
        perl-version \
        perl-JSON \
        perl-Net-INET6Glue \
        perl-Geo-IP \
        perl-CGI \
        httpd \
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

起動時に使用する設定ファイルを作成します。

    # mkdir -p /etc/sysconfig/smtpauth
    # cp data/centos6/filter.sysconfig /etc/sysconfig/smtpauth/filter
    # cp data/centos6/log-collector.sysconfig /etc/sysconfig/smtpauth/log-collector
    # vi /etc/sysconfig/smtpauth/log-collector

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

    client_address:<client address 1><tab>client_port:<client port 1><tab>connect_time:<connect_time 1><tab>sender:<sender 1><tab>eom_time:<eom_time><tab>recipient:<recipient 1><tab>size:<size 2><tab><country>:<country 1>
    client_address:<client address 2><tab>client_port:<client port 2><tab>connect_time:<connect_time 2><tab>sender:<sender 2><tab>eom_time:<eom_time><tab>recipient:<recipient 2.1><tab>recipient:<recipient 2.2><tab>size:<size 2><tab><country>:<country 2>
    sender:<sender 3><tab>client_address:<client address 3><tab>client_port:<client port 3><tab>eom_time:<eom_time><tab>recipient:<recipient 3><tab>connect_time:<connect_time 3><tab>size:<size 3><tab><country>:<country 3>
    ...

    <clinet_address>: SMTPクライアントのIP address。
    <clinet_port>: SMTPクライアントのSource port。MTAがSendmailの場合は、`confMILTER_MACROS_CONNECT`に`{client_addr}`マクロを追加することで出力可能。
    <auth_id>: SMTP認証のID。
    <sender>: エンベロープの送信者メールアドレス( MAIL From: )。
    <recipient>: エンベロープの宛先メールアドレス( RCPT To: )。
    <connect_time>: SMTPクライアントがMTAに接続した時刻。フォーマットは"YYYY-MM-DD HH:MM:SS %z"。
    <eom_time>: MTAがSMTPクライアントからメッセージを受信した時刻( End of message ".\r\n" )。フォーマットは"YYYY-MM-DD HH:MM:SS %z"。
    <size>: メッセージサイズ(bytes)。MTAがSendmailの時のみ、`confMILTER_MACROS_EOM`に`{msg_size}`マクロを追加することで出力可能。
    <country>: SMTPクライアントの国のコード
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


## LICENSE AND COPYRIGHT

Copyright (C) 2016 Toshifumi Sakaguchi

This program is distributed under the (Revised) BSD License:
<http://www.opensource.org/licenses/bsd-license.php>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of Toshifumi Sakaguchi's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

