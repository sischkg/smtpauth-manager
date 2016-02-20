# smtpauth-manager

Smtpauth-manager is an application that enables MTA to reject send mail with the ID of the SMTP authentication.
This application is Milter, it is used in conjunction with MTA, such as Postfix or Sendmail.
When you append SMTP authentication ID in the configuration file, so that you refuse to send mail from that ID.
And, in order to detect a mass-mail due sending spam, smtpauth-manager output maillog that is easy to read.

## REQUIREMENT

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

## INSTALLATION

### CentOS 6.6 + Postfix

Add epel repository.

    # yum -y install epel-release

Install required packages.

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

Install smtpauth-manager

    $ git clone https://github.com/sischkg/smtpauth-manager.git
    $ cd smtpauth-manager
    $ perl Makefile.PL
    $ make
    $ su
    # make install

Add user and group for smtpauth-manager

    # groupadd smtpauth-manager
    # useradd -g smtpauth-manager -d /noexistent -s /bin/false smtpauth-manager
    # gpasswd -a postfix smtpauth-manager

Make reject id file, this file is listed SMTP Auth ID that is denied, per line.

    # mkdir /etc/smtpauth
    # vi /etc/smtpauth/reject_ids.txt

    spammer
    virus
    evil

Make startup config files.

    # mkdir -p /etc/sysconfig/smtpauth
    # cp data/centos6/filter.sysconfig /etc/sysconfig/smtpauth/filter
    # cp data/centos6/log-collector.sysconfig /etc/sysconfig/smtpauth/log-collector

Make directory for log file.

    # mkdir -p /var/log/smtpauth /var/lib/smtpauth/rrd
    # chown smtpauth-manager:smtpauth-manager /var/log/smtpauth /var/lib/smtpauth/rrd

Copy init script.

    # cp data/centos6/smtpauth-manager /etc/init.d
    # chmod 744 /etc/init.d/smtpauth-manager
    # chkconfig --add smtpauth-manager

Enable service.

    # service smtpauth-manager start
    # chkconfig smtpauth-manager on

Milter configration to main.cf of Postfix.

    # vi /etc/postfix/main.cf
    
    smtpd_milters = unix:/var/run/smtpauth/filter.sock
    
    # postfix reload


## LOG FILE

If a client sent one message, smtpauth-manager store log to file( default: /var/log/smtpauth/stats.log ),
that format is following.

    client_address:<client address 1><tab>client_port:<client port 1><tab>connect_time:<connect_time 1><tab>sender:<sender 1><tab>eom_time:<eom_time><tab>recipient:<recipient 1><tab>size:<size 2><tab><country>:<country 1>
    client_address:<client address 2><tab>client_port:<client port 2><tab>connect_time:<connect_time 2><tab>sender:<sender 2><tab>eom_time:<eom_time><tab>recipient:<recipient 2.1><tab>recipient:<recipient 2.2><tab>size:<size 2><tab><country>:<country 2>
    sender:<sender 3><tab>client_address:<client address 3><tab>client_port:<client port 3><tab>eom_time:<eom_time><tab>recipient:<recipient 3><tab>connect_time:<connect_time 3><tab>size:<size 3><tab><country>:<country 3>
    ...

    <clinet address>: Client IP address.
    <clinet port>: Client source port.
    <auth_id>: SMTP AUTH ID.
    <sender>: Envelope from mail address( MAIL From: ).
    <recipient>: Envelope recipient address( RCPT To: ).
    <connect_time>: When SMTP Client connected to MTA. Format is YYYY-MM-DD HH:MM:SS.
    <eom_time>: When MTA received message from Client( End of message ".\r\n" ). Format YYYY-MM-DD HH:MM:SS.
    <size>: message size(bytes).
    <country>: code of client country.
    <tab>: TAB ("\t").

This format is nearly equal to LTSV format(<http://ltsv.org/>), but allows that same labels exist in one line.
Log file is rotated to /var/log/smtpauth/stats.log.YYYYMMDD every day.

## RRD

Smtpauth-manager saves coount of received and sent messages to RRD file.
RRD filename is /var/lib/smtpauth/rrd/stats.rrd.


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

