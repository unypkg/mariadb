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

cp -a support-files/systemd/* /etc/systemd/system
systemctl daemon-reload

if [[ ! -d /var/lib/mysql ]]; then
    scripts/mariadb-install-db --basedir="$unypkg_root_dir" --datadir=/var/lib/mysql --user=mysql
    chown -R mysql:mysql /var/lib/mysql
fi

#    install -v -m755 -o mysql -g mysql -d /run/mysqld &&
#        bin/mariadbd-safe --user=mysql 2>&1 >/dev/null &
#    mariadb-admin -u root password
#    mariadb-admin -p shutdown

#############################################################################################
### End of script

cd "$current_dir" || exit
