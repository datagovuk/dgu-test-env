#!/usr/bin/env bash

if [ ! $WORKSPACE ] ; then
  echo "No workspace configured, using pwd"
  WORKSPACE = `pwd`
fi

TEST_ROOT=$WORKSPACE
USER="ckantest"
CKAN_INI="pyenv/src/ckan/development.ini"

echo "Moving to $TEST_ROOT"
cd $TEST_ROOT

set -e 
set -x

# CKAN/Python setup
if [ ! -e pyenv ]
then
  virtualenv --no-site-packages pyenv
  mkdir -p pyenv/src
fi

. pyenv/bin/activate

[ -d pyenv/src/ckan ] || git clone git@github.com:datagovuk/ckan pyenv/src/ckan
cd pyenv/src/ckan
git checkout release-v1.7.1-dgu
cd $TEST_ROOT

[ -d pyenv/src/ckanext-archiver ] ||  git clone git@github.com:datagovuk/ckanext-archiver pyenv/src/ckanext-archiver
cd pyenv/src/ckanext-archiver
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-datapreview ] || git clone git@github.com:datagovuk/ckanext-datapreview pyenv/src/ckanext-datapreview
cd pyenv/src/ckanext-datapreview
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-dgu ] || git clone git@github.com:datagovuk/ckanext-dgu pyenv/src/ckanext-dgu
cd pyenv/src/ckanext-dgu
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-ga-report ] || git clone git@github.com:datagovuk/ckanext-ga-report pyenv/src/ckanext-ga-report
cd pyenv/src/ckanext-ga-report
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-harvest ] || git clone git@github.com:datagovuk/ckanext-harvest pyenv/src/ckanext-harvest
cd pyenv/src/ckanext-harvest
git checkout dgu
cd $TEST_ROOT

[ -d pyenv/src/ckanext-os ] || git clone git@github.com:datagovuk/ckanext-os pyenv/src/ckanext-os
cd pyenv/src/ckanext-os
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-qa ] || git clone git@github.com:datagovuk/ckanext-qa pyenv/src/ckanext-qa
cd pyenv/src/ckanext-qa
git checkout temp_working
cd $TEST_ROOT

[ -d pyenv/src/ckanext-social ] || git clone git@github.com:okfn/ckanext-social pyenv/src/ckanext-social
cd pyenv/src/ckanext-social
git checkout master
cd $TEST_ROOT

[ -d pyenv/src/ckanext-spatial ] || git clone git@github.com:datagovuk/ckanext-spatial pyenv/src/ckanext-spatial
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

cp ckan.ini.source pyenv/src/ckan/development.ini 

cd pyenv/src/ckanext-dgu
nosetests --with-pylons=test-core.ini ckanext/dgu/tests/
