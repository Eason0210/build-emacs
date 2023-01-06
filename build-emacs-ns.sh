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
SRC_DIR=$HOME/src/emacs-gnu/
# SITELISP=/Applications/Emacs.app/Contents/Resources/site-lisp
BASE_URL="https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs"

echo "
# ======================================================
# Start with a clean build
# ======================================================
"

rm -rf ${BUILD_DIR}
mkdir ${BUILD_DIR}

cd ${SRC_DIR}/../emacs-tarballs

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

[[ -n "$HOME/src/emacs-tarballs/${emacssrc}.tar.gz" ]] && rm "${emacssrc}.tar.gz" && echo "Removed the old ${emacssrc}.tar.gz"

echo "
Wget Will download source code from URL: $tarurl
"
echo "Current directory is: " && pwd

export https_proxy="http://127.0.0.1:8889"
export http_proxy="http://127.0.0.1:8889"

echo "
Now using https proxy!
"

wget $tarurl && echo "The ${emacssrc}.tar.gz have been download!"

# unzip

cd $SRC_DIR/../ && tar -xjf $SRC_DIR/../emacs-tarballs/${emacssrc}.tar.gz || echo "Ger error when tar -xjf ${emacssrc}.tar.gz"
echo "Unzipping ${emacssrc}.tar.gz suceeded! "

echo "
Moving ${emacssrc} to $SRC_DIR
"

[[ -n "$SRC_DIR" ]] && echo "The directory emacs-gnu allready existed, remove it." && rm -rf emacs-gnu

mv "$emacssrc" "emacs-gnu" && echo "Moved $emacssrc as emacs-gnu successfuly!"

echo "
# ======================================================
# Autogen/copy_autogen
# ======================================================
"

cd "emacs-gnu"
# Generate config files
./autogen.sh

# ======================================================
# Set Compile Flags
# ======================================================

# Use Clang for slightly faster builds
# See https://leeifrankjaw.github.io/articles/clang_vs_gcc_for_emacs.html
# See https://alibabatech.medium.com/gcc-vs-clang-llvm-an-in-depth-comparison-of-c-c-compilers-899ede2be378
# See https://docs.oracle.com/cd/E19957-01/806-3567/cc_options.html for CFLAG option explanations
# CFLAGS="-g -O2"
# export CC=clang
# export OBJC=clang

export LDFLAGS='-L/opt/local/lib -Wl,-headerpad_max_install_names -Wl,-rpath /opt/local/lib/gcc12 -Wl,-syslibroot,/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -arch x86_64'
export LIBRARY_PATH='/opt/local/lib/gcc12:/opt/local/lib'
export CPPFLAGS='-I/opt/local/include -isysroot/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk'
export CPATH='/opt/local/include/gcc12:/opt/local/include'

echo "
# ======================================================
# Configure emacs
# ======================================================
"

# Here we set config options for emacs For more info see config-options.txt.
# Note that this renames ctags in emacs so that it doesn't conflict with other
# installed ctags; see and don't compress info files, etc
# https://www.topbug.net/blog/2016/11/10/installing-emacs-from-source-avoid-the-conflict-of-ctags/
./configure

echo "
# ======================================================
# Build and install everything
# ======================================================
"

# Check number of processors & use as many as we can!
NCPU=$(expr $(getconf _NPROCESSORS_ONLN) / 2)

# Send output to log file using tee
# See https://stackoverflow.com/a/60432203/6277148
make -j$NCPU | tee bootstrap-log.txt || exit 1 && make install -j$NCPU | tee build-log.txt

echo "Build Emacs DONE!"

echo "
# ======================================================
# Delete old app & Move new app
# ======================================================
"

# Close any emacs sessions
pkill -i emacs

# Remove old emacs
# See https://stackoverflow.com/a/677212/6277148
# and https://stackoverflow.com/a/638980/6277148
# for discussion of confitional checks for files

if [ -e /Applications/Emacs.app ]
then
   if command -v trash </dev/null 2>&1
   then
    echo "Trashing old emacs..."
    trash /Applications/Emacs.app
   else
    echo "Removing old emacs..."
    rm -rf /Applications/Emacs.app
   fi
fi

# Move build to applications folder
mv ${SRC_DIR}/nextstep/Emacs.app /Applications/Emacs.app

echo "Move ${SRC_DIR}/nextstep/Emacs.app to /Applications folder DONE!"

echo "
# ======================================================
# Copy C Source Code
# ======================================================
"

# Copy C source files to Emacs
cp -r ${SRC_DIR}/src /Applications/Emacs.app/Contents/Resources/

echo "Copy C Source Code DONE!"

echo "
# ======================================================
# Create Log files
# ======================================================
"

# Make a directory for the build's log files and move them there
# Note that this removes a previous identical dir if making multiple similar builds

cur_dateTime="`date +%Y-%m-%d`"
echo "Current day is: $cur_dateTime"
mkdir -p ${ROOT_DIR}/build-logs/
mv ${SRC_DIR}/config.log ${ROOT_DIR}/build-logs/config-${cur_dateTime}.log
mv ${SRC_DIR}/build-log.txt ${ROOT_DIR}/build-logs/build-log-${cur_dateTime}.txt
mv ${SRC_DIR}/bootstrap-log.txt ${ROOT_DIR}/build-logs/bootstrap-log-${cur_dateTime}.txt

echo "Create Log files DONE!"

echo "
# ======================================================
# Cleanup
# ======================================================
"

# Delete build dir
# rm -rf ${BUILD_DIR}

# echo "DONE!"

echo "
# ======================================================
# Add executables to path
#
# Be sure to add /Applications/Emacs.app/Contents/MacOS/bin
# to your .zshrc or .profile path like so:
# export PATH=\$PATH:/Applications/Emacs.app/Contents/MacOS
# export PATH=\$PATH:/Applications/Emacs.app/Contents/MacOS/bin
# ======================================================
"

export PATH=$PATH:/Applications/Emacs.app/Contents/MacOS
export PATH=$PATH:/Applications/Emacs.app/Contents/MacOS/bin

echo "execs added to this terminal session -- please
modify $HOME/.zshrc or $HOME/.zshenv accordingly"

echo "
# ======================================================
# Open new emacs
# ======================================================
"

open /Applications/Emacs.app

END_DATE=$(date +"%s")
ELAPSED_TIME=$(($START_DATE-$END_DATE))

echo "Duration: $(expr $ELAPSED_TIME / 3600)h: $(expr $ELAPSED_TIME % 3600 / 60)m : $(expr $ELAPSED_TIME % 60)s"
echo "Build script finished!"
