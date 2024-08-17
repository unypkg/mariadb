#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

apt install -y jq

wget -qO- uny.nu/pkg | bash -s buildsys

### Installing build dependencies
unyp install cmake libxml2 libaio pcre2 libevent openssl curl boost fmt procps liburing lz4 jemalloc

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

latest_stable_ver_start="$(wget -O- -q https://downloads.mariadb.org/rest-api/mariadb/ | jq -r '[.major_releases[] | select(.release_support_type=="Long Term Support")][0].release_id')"

pkgname="mariadb"
pkggit="https://github.com/MariaDB/server.git refs/tags/mariadb-$latest_stable_ver_start*"
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

#cd "$pkg_git_repo_dir" || exit
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
libxml2_path=(/uny/pkg/libxml2/*)
libaio_path=(/uny/pkg/libaio/*)

cmake -DCMAKE_BUILD_TYPE=Release \
    -DWITH_LIBFMT=system \
    -DCMAKE_INSTALL_PREFIX=/uny/pkg/"$pkgname"/"$pkgver" \
    -DCURSES_LIBRARY="${ncurses_path[0]}"/lib/libncursesw.so \
    -DCURSES_INCLUDE_PATH="${ncurses_path[0]}"/include \
    -DLIBXML2_INCLUDE_DIR="${libxml2_path[0]}"/include \
    -DLIBAIO_LIBRARIES="${libaio_path[0]}"/lib/libaio.so \
    -DLIBAIO_INCLUDE_DIRS="${libaio_path[0]}"/include \
    -DGRN_LOG_PATH=/var/log/groonga.log \
    -DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
    -DMYSQL_DATADIR=/var/lib/mysql \
    -DDEFAULT_CHARSET=utf8mb4 \
    -DDEFAULT_COLLATION=utf8mb4_unicode_ci \
    -DENABLED_LOCAL_INFILE=ON \
    -DPLUGIN_EXAMPLE=NO \
    -DPLUGIN_FEDERATED=NO \
    -DPLUGIN_FEEDBACK=NO \
    -DWITH_EMBEDDED_SERVER=ON \
    -DWITH_EXTRA_CHARSETS=complex \
    -DWITH_JEMALLOC=ON \
    -DWITH_LIBWRAP=OFF \
    -DWITH_PCRE2=system \
    -DWITH_READLINE=ON \
    -DWITH_SSL=system \
    -DWITH_SYSTEMD=no \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_ZLIB=system \
    -DSKIP_TESTS=ON \
    -DTOKUDB_OK=0 \
    ..

make -j"$(nproc)"
make -j"$(nproc)" install

#cmake --build . --parallel="$(nproc)"
#cmake --install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
