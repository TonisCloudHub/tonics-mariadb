#!/bin/bash

# Launch Instance
lxc launch images:debian/bullseye/amd64 tonics-mariadb

# Dependencies
lxc exec tonics-mariadb -- apt install -y apt-transport-https curl
lxc exec tonics-mariadb -- mkdir -p /etc/apt/keyrings
lxc exec tonics-mariadb -- curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
lxc exec tonics-mariadb -- touch /etc/apt/sources.list.d/mariadb.sources

cat << EOF | sudo tee -a mariadb.sources
# MariaDB 10.11 repository list - created 2023-07-13 10:54 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# URIs: https://deb.mariadb.org/10.11/debian
URIs: https://mirrors.gigenet.com/mariadb/repo/10.11/debian
Suites: bullseye
Components: main
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF

lxc file push mariadb.sources tonics-mariadb/etc/apt/sources.list.d/mariadb.sources

# Install MariaDB
lxc exec tonics-mariadb -- apt update -y
lxc exec tonics-mariadb -- bash -c "DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server"

lxc exec tonics-mariadb -- bash -c "mysql --user=root -sf <<EOS
-- set root password
ALTER USER root@localhost IDENTIFIED BY 'tonics_cloud';
DELETE FROM mysql.user WHERE User='';
-- delete remote root capabilities
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
-- drop database 'test'
DROP DATABASE IF EXISTS test;
-- also make sure there are lingering permissions to it
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- make changes immediately
FLUSH PRIVILEGES;
EOS
"

# Clean Debian Cache
lxc exec tonics-mariadb -- apt clean

# MariaDB Version
Version=$(lxc exec tonics-mariadb -- mysql -V | awk '{print $5}' | sed 's/,//')

# Publish Image
mkdir images && lxc stop tonics-mariadb && lxc publish tonics-mariadb --alias tonics-mariadb

# Export Image
lxc start tonics-mariadb
lxc image export tonics-mariadb images/mariadb-bullseye-$Version

# Image Info
lxc image info tonics-mariadb >> images/info.txt
