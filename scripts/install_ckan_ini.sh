#!/usr/bin/env bash

CKAN_INI=$1

echo Creating your ckan.ini file from template...

if [ -z $CKAN_INI ]
then
  echo Usage: $0 /path/to/ckan.ini
  exit 1
fi

if [ ! -e ~/.pgpasswd ] 
then
  echo "No database password file exists (~/.passwd)."
  echo Cannot continue.
  exit 1
fi

cp /vagrant/ckan.ini.source $CKAN_INI
sed -i "s/%%PGPASSWD%%/`cat .pgpasswd`/" $CKAN_INI
sed -i "s/%%whofile%%/\/vagrant\/src\/ckan\/who.ini/" $CKAN_INI
sed -i "s/%%logfile%%/\/var\/log\/ckan\/ckan.log/" $CKAN_INI

echo Done.
