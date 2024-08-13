#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

##apt install -y autopoint

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install cmake libxml2 libaio pcre2 libevent openssl

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

pkgname="mariadb"
pkggit="https://github.com/MariaDB/server.git refs/tags/mariadb-*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "mariadb-[0-9.]+$" | tail --lines=1)"
latest_ver="$(echo "$latest_head" | grep -o "mariadb-[0-9.].*" | sed "s|mariadb-||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

#cd "$pkgname" || exit
#./autogen.sh
#cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
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

cmake -DCMAKE_BUILD_TYPE=mysql_release \
    -DCMAKE_INSTALL_PREFIX=/uny/pkg/"$pkgname"/"$pkgver" \
    -DCURSES_LIBRARY="${ncurses_path[0]}"/lib/libncursesw.so \
    -DCURSES_INCLUDE_PATH="${ncurses_path[0]}"/include \
    -DGRN_LOG_PATH=/var/log/groonga.log \
    -DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
    -DWITH_EXTRA_CHARSETS=complex \
    -DWITH_EMBEDDED_SERVER=ON \
    -DSKIP_TESTS=ON \
    -DTOKUDB_OK=0 \
    ..

cmake --build . --parallel="$(nproc)"
cmake --install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
