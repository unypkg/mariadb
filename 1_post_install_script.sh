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
# shellcheck disable=SC1003
sed -e '/\[Install\]/a\' -e 'Alias=mariadb.service mysqld.service mysql.service' -i /etc/systemd/system/uny-mariadb.service
systemctl daemon-reload

#    install -v -m755 -o mysql -g mysql -d /run/mysqld &&
#        bin/mariadbd-safe --user=mysql 2>&1 >/dev/null &
#    mariadb-admin -u root password
#    mariadb-admin -p shutdown

install -v -dm 755 -o mysql -g mysql /etc/uny/mariadb /etc/uny/mariadb/my.cnf.d

cp -a etc/my.cnf /etc/uny/mariadb
sed "s|/etc/my.cnf.d|/etc/uny/mariadb/my.cnf.d|" -i /etc/uny/mariadb/my.cnf

if [[ ! -s /etc/uny/mariadb/my.cnf.d/00-base.cnf ]]; then
    cat >/etc/uny/mariadb/my.cnf.d/00-base.cnf <<"EOF"
# Begin /etc/uny/mariadb/my.cnf.d/00-base.cnf

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
EOF
fi

if ! ls /var/lib/mysql/* >/dev/null 2>&1; then
    install -v -dm 755 -o mysql -g mysql /var/lib/mysql
    scripts/mariadb-install-db --basedir="$unypkg_root_dir" --datadir=/var/lib/mysql --user=mysql
fi

if [[ ! -d /run/mysqld ]]; then
    install -v -m755 -o mysql -g mysql -d /run/mysqld
fi

#############################################################################################
### End of script

cd "$current_dir" || exit
