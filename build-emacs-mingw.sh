#!/usr/bin/env bash

# ======================================================
# Uncomment `set -e' if you want script to exit
# on non-zero status
# See https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
# ======================================================

# set -e

# ======================================================
# Set Variables
# ======================================================
START_DATE=$(date +"%s")
ROOT_DIR="`pwd`"
BASE_URL="https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs"
INSTALL_DIR="/c/opt/emacs-build"

echo "
# ======================================================
# Start with a clean build
# ======================================================
"

mkdir -p "${ROOT_DIR}/emacs-tarballs"
cd "${ROOT_DIR}/emacs-tarballs"

# ======================================================
# Input commit-id or "master" otherwise default to emacs-29 branch
# ======================================================

# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-2569ede9c496bb060e0b88428cb541088aaba1f9.tar.gz
# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-emacs-29.tar.gz
# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-master.tar.gz

if test -n "$1"; then
    tarurl="${BASE_URL}-${1}.tar.gz"
    emacssrc="emacs-${1}"
else
    tarurl="${BASE_URL}-emacs-29.tar.gz"
    emacssrc="emacs-emacs-29"
fi

echo "Current directory is: " && pwd

tarball_file="${ROOT_DIR}/emacs-tarballs/${emacssrc}.tar.gz"
[[ -n "$tarball_file" ]] && rm "$tarball_file" && echo "Removed the $tarball_file"


echo "
Wget Will download source code from URL: $tarurl
"
echo "Current directory is: " && pwd

export https_proxy="http://127.0.0.1:8889"
export http_proxy="http://127.0.0.1:8889"

echo "
Now using https proxy!
"

wget $tarurl && echo "The ${tarball_file} have been download!"

# unzip

TAR_CMD="/c/Windows/system32/tar.exe"
cd "$ROOT_DIR/emacs-tarballs" && $TAR_CMD -xjf "${ROOT_DIR}/emacs-tarballs/${emacssrc}.tar.gz" || echo "Ger error when tar -xjf ${emacssrc}.tar.gz"
echo "Unzipping ${emacssrc}.tar.gz suceeded! "

cd "${ROOT_DIR}/emacs-tarballs/${emacssrc}"
echo "Current directory is: " && pwd

SRC_DIR="${ROOT_DIR}/emacs-tarballs/${emacssrc}"

echo "
# ======================================================
# Autogen/copy_autogen
# ======================================================
"

# Generate config files
./autogen.sh

# ======================================================
# Set Compile Flags
# ======================================================


echo "
# ======================================================
# Configure emacs
# ======================================================
"

# Here we set config options for emacs For more info see config-options.txt.
# Note that this renames ctags in emacs so that it doesn't conflict with other
# installed ctags; see and don't compress info files, etc
# https://www.topbug.net/blog/2016/11/10/installing-emacs-from-source-avoid-the-conflict-of-ctags/

./configure \
    --with-native-compilation=aot \
    --without-dbus \

echo "
# ======================================================
# Build and install everything
# ======================================================
"
# If "$INSTALL_DIR" exit, remove it and create a new one
[[ -n "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR"

# if "$INSTALL_DIR" not exit, create a new one
[[ -z "$INSTALL_DIR" ]] || mkdir -p "$INSTALL_DIR"

# Check number of processors & use as many as we can!
NCPU=$(expr $(getconf _NPROCESSORS_ONLN) / 2)

# Send output to log file using tee
# See https://stackoverflow.com/a/60432203/6277148
make -j$NCPU | tee bootstrap-log.txt || exit 1 && make install -j$NCPU prefix=$INSTALL_DIR | tee build-log.txt

echo "Build Emacs DONE!"


echo "
# ======================================================
# Create Log files
# ======================================================
"

# Make a directory for the build's log files and move them there
# Note that this removes a previous identical dir if making multiple similar builds


cur_dateTime="`date +%Y-%m-%d`"-T"`date +%H-%M-%S`"
echo "Current day is: $cur_dateTime"
mkdir -p ${ROOT_DIR}/build-logs/
mv "${SRC_DIR}/config.log" "${ROOT_DIR}/build-logs/config-${cur_dateTime}.log"
mv "${SRC_DIR}/build-log.txt" "${ROOT_DIR}/build-logs/build-log-${cur_dateTime}.txt"
mv "${SRC_DIR}/bootstrap-log.txt" "${ROOT_DIR}/build-logs/bootstrap-log-${cur_dateTime}.txt"

echo "Create Log files DONE!"

echo "
# ======================================================
# Cleanup
# ======================================================
"

# Delete build dir
rm -rf ${SRC_DIR}

echo "DONE!"

echo "
# ======================================================
# Please rename C:\opt\emacs-build to C:\opt\emacs
# And add C:\opt\emacs\bin to your Path environment
# ======================================================
"

END_DATE=$(date +"%s")
ELAPSED_TIME=$(($END_DATE-$START_DATE))

echo "Duration: $(expr $ELAPSED_TIME / 3600)h: $(expr $ELAPSED_TIME % 3600 / 60)m : $(expr $ELAPSED_TIME % 60)s"
echo "Build script finished!"
