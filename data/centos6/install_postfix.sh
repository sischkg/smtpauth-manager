#!/bin/sh

USER=smtpauth-manager
GROUP=smtpauth-manager
INIT_SCRIPTS="smtpauth-manager smtpauth-filter smtpauth-log-collector"
SYSCONFIG_FILES="filter log-collector"
 
if ! getent group $GROUP 
then
    groupadd $GROUP
fi

if ! getent passwd $USER 
then
    useradd -g $GROUP -d /noexistent -s /bin/false $USER
fi

if getent passwd postfix
then
    gpasswd -a postfix $GROUP
fi

mkdir -p /etc/smtpauth /etc/sysconfig/smtpauth
touch /etc/smtpauth/reject_ids.txt
mkdir -p /var/log/smtpauth
chown $USER:$GROUP /var/log/smtpauth
mkdir -p /var/lib/smtpauth/rrd
chown $USER:$GROUP /var/log/smtpauth

for script in $INIT_SCRIPTS
do
    cp $script /etc/init.d
    chmod 744 /etc/init.d/$script
    chkconfig --add $script
done

for config in $SYSCONFIG_FILES
do
    cp $config.sysconfig /etc/sysconfig/smtpauth/$config
done




