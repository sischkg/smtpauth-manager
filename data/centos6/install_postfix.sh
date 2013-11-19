#!/bin/sh

USER=smtpauth-manager
GROUP=smtpauth-manager

if ! getent group $GROUP 
then
    groupadd $GROUP
fi

if ! getent passwd $USER 
then
    useradd -g $GROUP -d /noexistent -s /bin/false $USER
fi

if ! getent passwd postfix
then
    gpasswd -a postfix $GROUP
fi

mkdir -p /etc/smtpauth-filter/
touch /etc/smtpauth-filter/reject_ids.txt
mkdir -p /var/log/smtpauth
chown $USER:$GROUP /var/log/smtpauth
cp smtpauth-manager /etc/init.d
chmod 744 /etc/init.d/smtpauth-manager
chkconfig --add smtpauth-manager

