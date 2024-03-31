#!/bin/bash

# Init incus
sudo incus admin init --auto

# Launch Instance
sudo incus launch images:debian/bookworm/amd64 tonics-mariadb

# Dependencies
sudo incus exec tonics-mariadb -- bash -c "apt update -y && apt upgrade -y"

sudo incus exec tonics-mariadb -- bash -c "DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server"

sudo incus exec tonics-mariadb -- bash -c "mysql --user=root -sf <<EOS
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
sudo incus exec tonics-mariadb -- bash -c "apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*"

# MariaDB Version
Version=$(sudo incus exec tonics-mariadb -- mysql -V | awk '{print $5}' | sed 's/,//')

# Publish Image
mkdir images && sudo incus stop tonics-mariadb && sudo incus publish tonics-mariadb --alias tonics-mariadb

# Export Image
sudo incus start tonics-mariadb
sudo incus image export tonics-mariadb images/mariadb-bookworm-$Version

# Image Info
sudo incus image info tonics-mariadb >> images/info.txt
