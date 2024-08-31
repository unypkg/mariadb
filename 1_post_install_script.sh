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

#############################################################################################
### End of script

cd "$current_dir" || exit
