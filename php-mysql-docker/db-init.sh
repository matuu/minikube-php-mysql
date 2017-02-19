#!/bin/bash
: ${MYSQL_ROOT_PASSWORD?}
set -x
mysql -u root -p$MYSQL_ROOT_PASSWORD -h 127.0.0.1 -e "GRANT ALL PRIVILEGES ON *.* TO 'webapp'@'%' IDENTIFIED BY 'qpwoeiruty';" 
mysql -u root -p$MYSQL_ROOT_PASSWORD -h 127.0.0.1 -e "CREATE DATABASE IF NOT EXISTS webapp_db;"
# Exit on error:
[ $? -eq 0 ] || exit 1

( cd /var/www/html/php-mysql
  test -f db.php.bak && exit 0 # edit only once
  sed -i.bak \
      -e 's/mysql_username = "root"/mysql_username = "webapp"/g' \
      -e 's/mysql_password = ""/mysql_password = "qpwoeiruty"/g' \
      -e 's/mysql_database = "test"/mysql_database = "webapp_db"/g' \
       db.php
)

