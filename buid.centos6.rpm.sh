#!/bin/sh

source_name=`dirname $0`

RPMBUILD_DIR=$HOME/rpmbuild


( cd $source_name && perl Makefile.PL && make dist )
last_source=`ls $source_name/Milter-SMTPAuth-*.tar.gz|sort|tail -n 1`
spec=$source_name/data/centos6/smtpauth-manager.spec

echo $last_source
echo $spec

cp $last_source $RPMBUILD_DIR/SOURCES
cp $spec        $RPMBUILD_DIR/SPECS
( cd $RPMBUILD_DIR && rpmbuild -ba SPECS/smtpauth-manager.spec )

