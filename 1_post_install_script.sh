#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

groupadd -r mysql
useradd -c "MySQL Server" -d /var/lib/mysql -g mysql -s /bin/false -r mysql

cp -a support-files/systemd/mariadb.service /etc/systemd/system/uny-mariadb.service
#sed "s|.*Alias=.*||g" -i /etc/systemd/system/uny-mariadb.service
sed -e '/\[Install\]/a\' -e 'Alias=mariadb.service mysqld.service mysql.service' -i /etc/systemd/system/uny-mariadb.service
systemctl daemon-reload

if [[ ! -d /var/lib/mysql ]]; then
    scripts/mariadb-install-db --basedir="$unypkg_root_dir" --datadir=/var/lib/mysql --user=mysql
    chown -R mysql:mysql /var/lib/mysql
fi

if [[ ! -d /run/mysqld ]]; then
    install -v -m755 -o mysql -g mysql -d /run/mysqld
fi

#    install -v -m755 -o mysql -g mysql -d /run/mysqld &&
#        bin/mariadbd-safe --user=mysql 2>&1 >/dev/null &
#    mariadb-admin -u root password
#    mariadb-admin -p shutdown

install -v -dm 755 -o mysql -g mysql /etc/uny/mariadb

if [[ ! -s /etc/uny/mariadb/my.cnf ]]; then
    cat >/etc/uny/mariadb/my.cnf <<"EOF"
# Begin /etc/uny/mariadb/my.cnf

# The following options will be passed to all MySQL clients
[client]
#password       = your_password
port            = 3306
socket          = /run/mysqld/mysqld.sock

# The MySQL server
[mysqld]
port            = 3306
socket          = /run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
skip-external-locking
key_buffer_size = 16M
max_allowed_packet = 1M
sort_buffer_size = 512K
net_buffer_length = 16K
myisam_sort_buffer_size = 8M

# Don't listen on a TCP/IP port at all.
skip-networking

# required unique id between 1 and 2^32 - 1
server-id       = 1

# Uncomment the following if you are using BDB tables
#bdb_cache_size = 4M
#bdb_max_lock = 10000

# InnoDB tables are now used by default
innodb_data_home_dir = /srv/mysql
innodb_log_group_home_dir = /srv/mysql
# All the innodb_xxx values below are the default ones:
innodb_data_file_path = ibdata1:12M:autoextend
# You can set .._buffer_pool_size up to 50 - 80 %
# of RAM but beware of setting memory usage too high
innodb_buffer_pool_size = 128M
innodb_log_file_size = 48M
innodb_log_buffer_size = 16M
innodb_flush_log_at_trx_commit = 1
innodb_lock_wait_timeout = 50

[mysqldump]
quick
max_allowed_packet = 16M

[mysql]
no-auto-rehash
# Remove the next comment character if you are not familiar with SQL
#safe-updates

[isamchk]
key_buffer = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[myisamchk]
key_buffer_size = 20M
sort_buffer_size = 20M
read_buffer = 2M
write_buffer = 2M

[mysqlhotcopy]
interactive-timeout

# End /etc/mysql/my.cnf
EOF
fi

#############################################################################################
### End of script

cd "$current_dir" || exit
