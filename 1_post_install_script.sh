#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

current_dir="$(pwd)"
unypkg_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
unypkg_root_dir="$(cd -- "$unypkg_script_dir"/.. &>/dev/null && pwd)"

cd "$unypkg_root_dir" || exit

#############################################################################################
### Start of script

groupadd -g 40 mysql
useradd -c "MySQL Server" -d /var/lib/mysql -g mysql -s /bin/false -u 40 mysql

cp -a support-files/systemd/* /etc/systemd/system
systemctl daemon-reload

if [[ ! -d /var/lib/mysql ]]; then
    mysql_install_db --basedir="$unypkg_root_dir" --datadir=/var/lib/mysql --user=mysql
    chown -R mysql:mysql /var/lib/mysql
fi

#############################################################################################
### End of script

cd "$current_dir" || exit
