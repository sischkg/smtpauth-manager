%global		uid	smtpauth-manager
%global		gid	smtpauth-manager
%global		Src Milter-SMTPAuth-%{version}

Name:		perl-Milter-SMTPAuth
Version:	0.5.2
Release:	1%{?dist}
Summary:	smtpauth-manager is milter application for managing to send messages by SMTP AUTH ID.


Group:		Applications/Internet
License:	BSD
URL:		https://github.com/sischkg/smtpauth-manager
Source0:	Milter-SMTPAuth-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	perl
BuildRequires:	perl-Moose
BuildRequires:	perl-MooseX-Getopt
BuildRequires:	perl-MooseX-Types
BuildRequires:	perl-MooseX-Types-Path-Class
BuildRequires:	perl-MooseX-Daemonize
BuildRequires:	perl-Mouse
BuildRequires:	perl-Readonly
BuildRequires:	perltidy
BuildRequires:	perl-Exception-Class
BuildRequires:	rrdtool-perl
BuildRequires:	perl-Authen-SASL
BuildRequires:	perl-Email-Address
BuildRequires:	perl-Time-Piece
Requires:	perl
Requires:	perl-Moose
Requires:	perl-MooseX-Getopt
Requires:	perl-MooseX-Types
Requires:	perl-MooseX-Types-Path-Class
Requires:	perl-MooseX-Daemonize
Requires:	perl-Mouse
Requires:	perl-Readonly
Requires:	perltidy
Requires:	perl-Exception-Class
Requires:	rrdtool-perl
Requires:	perl-Sendmail-PMilter
Requires:	perl-Authen-SASL
Requires:	perl-Email-Address
Requires:	perl-Time-Piece
Requires:	chkconfig

%description
smtpauth-manager is milter application for managing to send messages by SMTP AUTH ID.


%prep
%setup -q -n Milter-SMTPAuth-%{version}


%build
perl Makefile.PL PREFIX=/usr
make %{?_smp_mflags}


%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

mkdir -p %{buildroot}/etc/init.d
mkdir -p %{buildroot}/etc/smtpauth
mkdir -p %{buildroot}/etc/sysconfig/smtpauth
touch %{buildroot}/etc/smtpauth/reject_ids.txt
mkdir -p %{buildroot}/var/log/smtpauth
mkdir -p %{buildroot}/var/lib/smtpauth/rrd

for script in smtpauth-manager smtpauth-filter smtpauth-log-collector
do
    cat data/centos6/$script | \
      sed -e '#^PREFIX=.*$#PREFIX=/usr#' > \
      %{buildroot}/etc/init.d/$script
    chmod 744 %{buildroot}/etc/init.d/$script
done

for config in filter log-collector
do
    cp data/centos6/$config.sysconfig %{buildroot}/etc/sysconfig/smtpauth/$config
done


%pre
 
if ! getent group %{gid} > /dev/null
then
    groupadd %{gid}
fi

if ! getent passwd %{uid} > /dev/null
then
    useradd -g %{gid} -d /noexistent -s /bin/false %{uid}
fi

if getent passwd postfix > /dev/null
then
    gpasswd -a postfix %{gid} > /dev/null
fi

%post

for script in smtpauth-manager smtpauth-filter smtpauth-log-collector
do
    chkconfig --add $script
done


%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
/usr/bin/smtpauth-manager
/usr/bin/smtpauth-filter
/usr/bin/smtpauth-log-collector
/usr/bin/smtpauth-logger
/usr/bin/smtpauth-test
/usr/lib64/perl5/auto/Milter/SMTPAuth/.packlist
/usr/lib64/perl5/perllocal.pod
/usr/share/perl5/Milter/SMTPAuth.pm
/usr/share/perl5/Milter/SMTPAuth/AccessDB.pm
/usr/share/perl5/Milter/SMTPAuth/AccessDB/File.pm
/usr/share/perl5/Milter/SMTPAuth/Exception.pm
/usr/share/perl5/Milter/SMTPAuth/Filter.pm
/usr/share/perl5/Milter/SMTPAuth/Logger.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/Client.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/File.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/Formatter.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/LTSV.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/Outputter.pm
/usr/share/perl5/Milter/SMTPAuth/Logger/RRDTool.pm
/usr/share/perl5/Milter/SMTPAuth/Message.pm
/usr/share/perl5/Milter/SMTPAuth/Utils.pm
/usr/share/perl5/Milter/SMTPAuth/smtpauth-manager.pod
/etc/smtpauth
/etc/smtpauth/reject_ids.txt
/etc/sysconfig/smtpauth
/etc/sysconfig/smtpauth/filter
/etc/sysconfig/smtpauth/log-collector
/etc/init.d/smtpauth-manager
/etc/init.d/smtpauth-filter
/etc/init.d/smtpauth-log-collector
%defattr(-,%{uid},%{gid},-)
/var/log/smtpauth
/var/lib/smtpauth/rrd


%doc
/usr/share/man/man3/Milter::SMTPAuth.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::AccessDB::File.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Filter.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Logger.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Logger::Client.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Logger::File.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Logger::LTSV.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::Message.3pm.gz
/usr/share/man/man3/Milter::SMTPAuth::smtpauth-manager.3pm.gz

%changelog

