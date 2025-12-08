#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y jq

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install cmake libxml2 pcre2 libevent openssl curl boost fmt procps liburing lz4 jemalloc ncurses systemd git

#cp -a /uny/pkg/ncurses/*/include/*/* /uny/pkg/ncurses/*/include/

#pip3_bin=(/uny/pkg/python/*/bin/pip3)
#"${pip3_bin[0]}" install --upgrade pip
#"${pip3_bin[0]}" install docutils pygments

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

latest_stable_ver_start="$(wget -O- -q https://downloads.mariadb.org/rest-api/mariadb/ |
    jq -r '[.major_releases[] | select(.release_status=="Stable") | select(.release_support_type=="Long Term Support")][0].release_id')"

pkgname="mariadb"
pkggit="https://github.com/MariaDB/server.git"
refs="refs/tags/mariadb-$latest_stable_ver_start.*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep "$refs" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "mariadb-[0-9.].*" | sed "s|mariadb-||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

#cd "$pkg_git_repo_dir" || exit
#cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vxe
source /uny/git/unypkg/fn

pkgname="mariadb"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

unset LD_RUN_PATH

mkdir build
cd build || exit

ncurses_path=(/uny/pkg/ncurses/*)
libxml2_path=(/uny/pkg/libxml2/*)
pcre2_path=(/uny/pkg/pcre2/*)
liburing_path=(/uny/pkg/liburing/*)

export CFLAGS="-I${ncurses_path[0]}/include/ncursesw -I${pcre2_path[0]}/include" #-I${liburing_path[0]}/include
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_CONFIG=mysql_release \
    -D WITH_LIBFMT=system \
    -W no-dev \
    -D WITH_PCRE=system \
    -D PCRE_LIBRARY_DIRS="${pcre2_path[0]}"/lib \
    -D PCRE_INCLUDE_DIRS="${pcre2_path[0]}"/include \
    -D CMAKE_INSTALL_PREFIX=/uny/pkg/"$pkgname"/"$pkgver" \
    -D CURSES_INCLUDE_PATH="${ncurses_path[0]}"/include/ncursesw \
    -D LIBXML2_INCLUDE_DIR="${libxml2_path[0]}"/include \
    -D WITH_URING=ON \
    -D URING_LIBRARIES="${liburing_path[0]}"/lib/liburing.so \
    -D URING_INCLUDE_DIRS="${liburing_path[0]}"/include \
    -D GRN_LOG_PATH=/var/log/groonga.log \
    -D MYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
    -D MYSQL_DATADIR=/var/lib/mysql \
    -D INSTALL_SYSCONFDIR=/etc/uny/mariadb \
    -D DEFAULT_CHARSET=utf8mb4 \
    -D CONC_DEFAULT_CHARSET=utf8mb4 \
    -D DEFAULT_COLLATION=utf8mb4_unicode_ci \
    -D ENABLED_LOCAL_INFILE=ON \
    -D PLUGIN_EXAMPLE=NO \
    -D PLUGIN_FEDERATED=NO \
    -D PLUGIN_FEEDBACK=NO \
    -D WITH_EMBEDDED_SERVER=ON \
    -D WITH_EXTRA_CHARSETS=complex \
    -D WITH_JEMALLOC=ON \
    -D WITH_LIBWRAP=OFF \
    -D WITH_READLINE=ON \
    -D WITH_SSL=system \
    -D WITH_UNIT_TESTS=OFF \
    -D CONC_WITH_UNIT_TESTS=OFF \
    -D WITH_ZLIB=system \
    -D SKIP_TESTS=ON \
    -D TOKUDB_OK=0 \
    -D WITH_COMMENT="unypkg" \
    -D INSTALL_MYSQLTESTDIR="" \
    -D INSTALL_SQLBENCHDIR="" \
    -D PLUGIN_AUTH_PAM=NO \
    -D PLUGIN_AWS_KEY_MANAGEMENT=NO \
    -D WITH_SYSTEMD=yes \
    ..

#    -D WITHOUT_CLIENTLIBS=YES \

make -j"$(nproc)"
make -j"$(nproc)" install

mkdir -pv /uny/pkg/"$pkgname"/"$pkgver"/etc
cp -a /etc/uny/mariadb/* /uny/pkg/"$pkgname"/"$pkgver"/etc
sed "s|/etc/my.cnf.d|/etc/uny/mariadb/my.cnf.d|" -i /uny/pkg/"$pkgname"/"$pkgver"/etc/my.cnf

sed "s|# OOMScoreAdjust=|OOMScoreAdjust=|" -i /uny/pkg/"$pkgname"/"$pkgver"/support-files/systemd/mariadb.service
sed "s|Restart=on-abort|Restart=on-abnormal|" -i /uny/pkg/"$pkgname"/"$pkgver"/support-files/systemd/mariadb.service

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
