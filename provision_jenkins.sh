#!/usr/bin/env bash

if [ ! $WORKSPACE ] ; then
  echo "No workspace configured, using pwd"
  WORKSPACE = `pwd`
fi

echo "Moving to $TEST_ROOT"
cd $TEST_ROOT

TEST_ROOT=$WORKSPACE
USER="ckantest"
CKAN_INI="pyenv/src/ckan/development.ini"

set -e 
set -x

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
  mkdir -p pyenv/src
fi
source pyenv/bin/activate

git clone git@github.com:datagovuk/ckan pyenv/src/ckan
cd pyenv/src/ckan
git checkout release-v1.7.1-dgu
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-archiver pyenv/src/ckanext-archiver
cd ckanext-archiver
git checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-datapreview pyenv/src/ckanext-datapreview
cd ckanext-datapreview
git pyenv/src/checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-dgu pyenv/src/ckanext-dgu
cd pyenv/src/ckanext-dgu
git checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-ga-report pyenv/src/ckanext-ga-report
cd pyenv/src/ckanext-ga-report
git checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-harvest pyenv/src/ckanext-harvest
cd pyenv/src/ckanext-harvest
git checkout dgu
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-os pyenv/src/ckanext-os
cd pyenv/src/ckanext-os
git checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-qa pyenv/src/ckanext-qa
cd pyenv/src/ckanext-qa
git checkout temp_working
cd $TEST_ROOT

git clone git@github.com:okfn/ckanext-social pyenv/src/ckanext-social
cd pyenv/src/ckanext-social
git checkout master
cd $TEST_ROOT

git clone git@github.com:datagovuk/ckanext-spatial pyenv/src/ckanext-spatial
cd pyenv/src/ckanext-spatial
git checkout dgu
cd $TEST_ROOT

# CKAN codebase
pip install -e pyenv/src/ckan
pip install -e pyenv/src/ckanext-dgu
pip install -e pyenv/src/ckanext-os
pip install -e pyenv/src/ckanext-qa
pip install -e pyenv/src/ckanext-spatial
pip install -e pyenv/src/ckanext-harvest
pip install -e pyenv/src/ckanext-archiver
pip install -e pyenv/src/ckanext-social
pip install -e pyenv/src/ckanext-ga-report
pip install -e pyenv/src/ckanext-datapreview

# Paster is broken and needs to be installed in this order
pip install Paste==1.7.2
pip install PasteDeploy==1.5.0
pip install PasteScript==1.7.5
# CKAN Python dependancies
pip install -r pip-dependancies.txt

#dgu-test-env/scripts/install_ckan_ini.sh $CKAN_INI

if [ ! $(postgres_user_exists ckanuser) ] ; then
  psql -d postgres -c "create user ckanuser nocreatedb nocreateuser password '`cat .pgpasswd`';"
fi
if [ ! $(postgres_database_ready ckan) ] ; then 
  createdb -O ckanuser ckan --template template_postgis
fi


