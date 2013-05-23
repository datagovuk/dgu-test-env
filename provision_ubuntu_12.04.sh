#!/usr/bin/env bash

USER=`whoami`
# You know, I think it actually has to be in this place :-/
CKAN_INI=/vagrant/src/ckan/development.ini

# Exit if anything goes wrong
set -e 
# Print commands as they are executed
set -x

# Use my sudoers file
sudo cp /vagrant/etc/sudoers /etc/sudoers

# Postgres and Postgis
# ====================
postgres_user_exists() {
  USER=$1
  RESULT=`sudo -u postgres psql -c "select 1 from pg_roles where rolname='$USER';" | wc -l`
  # Query outputs 5 lines if user exists. 4 otherwise.
  echo $RESULT -eq 5 
}
postgres_database_ready() {
  DATABASE=$1
  sudo -u postgres psql -d $DATABASE -c "select postgis_lib_version();" >/dev/null 2>&1
  echo $? -eq 0
}

# Prepare packages
sudo apt-get update
sudo apt-get -y upgrade
# Install postgres and postgis (Requires Ubuntu 12.xx, probably works on 11.xx)
sudo apt-get -y install postgresql 
sudo apt-get -y install postgresql-contrib
sudo apt-get -y install postgresql-9.1-postgis
sudo apt-get -y install apache2
sudo apt-get -y install build-essential 
sudo apt-get -y install libpq-dev 
sudo apt-get -y install git-core 
sudo apt-get -y install subversion
sudo apt-get -y install mercurial
sudo apt-get -y install python-virtualenv 
sudo apt-get -y install python-psycopg2 
sudo apt-get -y install openjdk-6-jre-headless 
sudo apt-get -y install daemon
sudo apt-get -y install libapache2-mod-wsgi
sudo apt-get -y install libxslt1-dev 
sudo apt-get -y install python-pastescript
sudo apt-get -y build-dep python-psycopg2 

# Random postgres password
if [ ! -f .pgpasswd ]
then
  openssl rand -hex 16 -out .pgpasswd
  chmod 600 .pgpasswd
fi

if [ ! $(postgres_user_exists $USER) ] ; then
  sudo -u postgres createuser --superuser $USER 2>/dev/null
fi

if [ ! $(postgres_database_ready template_postgis) ] ; then
  echo 'Creating template PostGIS database...'
  createdb template_postgis
  #sudo -u postgres createlang -d template_postgis plpgsql;
  psql -d template_postgis -c "CREATE EXTENSION hstore;"
  psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-1.5/postgis.sql
  psql -d template_postgis -f /usr/share/postgresql/9.1/contrib/postgis-1.5/spatial_ref_sys.sql
  psql -d template_postgis -c "select postgis_lib_version();" 
  psql -d template_postgis -c "GRANT ALL ON geometry_columns TO PUBLIC;"
  psql -d template_postgis -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"
  psql -d template_postgis -c "GRANT ALL ON geography_columns TO PUBLIC;"
else
  echo 'Skipping creation of template PostGIS database.'
fi

# CKAN/Python setup
if [ ! -e pyenv ]
then
  virtualenv --no-site-packages pyenv
fi
source pyenv/bin/activate
# CKAN codebase
pip install -e /vagrant/src/ckan
pip install -e /vagrant/src/ckanext-dgu
pip install -e /vagrant/src/ckanext-os
pip install -e /vagrant/src/ckanext-qa
pip install -e /vagrant/src/ckanext-spatial
pip install -e /vagrant/src/ckanext-harvest
pip install -e /vagrant/src/ckanext-archiver
pip install -e /vagrant/src/ckanext-social
pip install -e /vagrant/src/ckanext-ga-report
pip install -e /vagrant/src/ckanext-datapreview
# Paster is broken and needs to be installed in this order
pip install Paste==1.7.2
pip install PasteDeploy==1.5.0
pip install PasteScript==1.7.5
# CKAN Python dependancies
pip install -r /vagrant/pip-vagrant-dependancies.txt
# CKAN logging 
mkdir -p {data,sstore}
chmod g+w {data,sstore}
sudo chgrp www-data {data,sstore}
ln -fs ~/sstore /vagrant/src/ckan/
ln -fs ~/data /vagrant/src/ckan/
sudo mkdir -p /var/log/ckan
sudo touch /var/log/ckan/ckan.log
sudo chown -R $USER /var/log/ckan
sudo chmod -R g+w /var/log/ckan
sudo chgrp -R www-data /var/log/ckan
# CKAN.ini file
/vagrant/scripts/install_ckan_ini.sh $CKAN_INI

# Apache Solr
sudo mkdir -p /var/log/solr
sudo chgrp $USER /var/log/solr
sudo chmod g+w /var/log/solr
if [ ! -e /usr/local/solr ]
then
  wget http://archive.apache.org/dist/lucene/solr/3.3.0/apache-solr-3.3.0.tgz
  tar -vxzf apache-solr-3.3.0.tgz
  sudo mv apache-solr-3.3.0 /usr/local/solr
  sudo mv /usr/local/solr/example/solr/conf/schema.xml{,.orig}
fi
ln -fs /vagrant/src/ckanext-dgu/config/solr/schema-1.4-dgu.xml /usr/local/solr/example/solr/conf/schema.xml
if [ ! -e /etc/init.d/solr ]
then
  sudo ln -fs /vagrant/etc/init.d/solr /etc/init.d/solr
  sudo update-rc.d solr defaults
fi
### Start solr and wait for daemon to be ready
sudo /etc/init.d/solr start
echo "Waiting for SOLR server..."
while ! nc -vz localhost 8983; do sleep 1; done
echo "SOLR is ready."

if [ ! $(postgres_user_exists ckanuser) ] ; then
  psql -d postgres -c "create user ckanuser nocreatedb nocreateuser password '`cat .pgpasswd`';"
fi
if [ ! $(postgres_database_ready ckan) ] ; then 
  createdb -O ckanuser ckan --template template_postgis
  paster --plugin=ckan db init --config=$CKAN_INI 
  cd /vagrant/src/ckanext-ga-report 
  paster initdb --config=$CKAN_INI
  cd -
  paster --plugin=ckanext-dgu create-test-data --config=$CKAN_INI
  paster --plugin=ckan search-index rebuild --config=$CKAN_INI
fi

# Set up Apache webserver
sudo ln -fs /vagrant/etc/apache2/sites-available/ckan /etc/apache2/sites-available/
sudo a2dissite default
sudo a2ensite ckan
sudo /etc/init.d/apache2 restart

