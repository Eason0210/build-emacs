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
ROOT_DIR="$(pwd)"
BUILD_DIR="${ROOT_DIR}/build"
SRC_BASE_URL="https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs"

# Default commit from emacs-29 branch
# https://git.savannah.gnu.org/cgit/emacs.git/commit/?h=emacs-29&id=20f36c8f6f98478dd86ddfe93da2803de2518ea2
REV_COMMIT="20f36c8f6f98478dd86ddfe93da2803de2518ea2"

# Use on Windows OS only
INSTALL_DIR="/c/opt/emacs-build"

# Set to "OFF" to turn off proxy
PROXY="ON"

# Native compilation
NATIVE_COMP="--with-native-compilation=aot"

NATIVE_COMP_LIST=(
    "--with-native-compilation=aot"
    "--with-native-compilation"
    "--without-native-compilation"
)

for value; do

    if [[ " ${NATIVE_COMP_LIST[*]} " =~ " ${value} " ]]; then
        NATIVE_COMP=${value}
    fi
done

echo "native-comp: ${NATIVE_COMP}"


echo "
# ======================================================
# Start with a clean build
# ======================================================
"

[[ -d "${BUILD_DIR}" ]] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

mkdir -p "${ROOT_DIR}/tarballs"
cd "${ROOT_DIR}/tarballs"


# ======================================================
# Input commit-id or "master" otherwise default to emacs-29 branch
# ======================================================

# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-2569ede9c496bb060e0b88428cb541088aaba1f9.tar.gz
# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-emacs-29.tar.gz
# https://git.savannah.gnu.org/cgit/emacs.git/snapshot/emacs-master.tar.gz

# Check for valid Git commit hash
GIT_COMMIT=$1
if [[ "$GIT_COMMIT" = "master" || "$GIT_COMMIT" = "emacs-29" || "$GIT_COMMIT" =~ ^[a-zA-Z0-9]{40}$ ]]; then
    echo "Git commit hash is valid."
    emacs_src_url="${SRC_BASE_URL}-${GIT_COMMIT}.tar.gz"
    emacs_src="emacs-${GIT_COMMIT}"
    REV_COMMIT=$GIT_COMMIT
elif [[ -z "$1" ]] || [[ "$1" = "${NATIVE_COMP}" ]]; then
    echo "The emacs-29 ${REV_COMMIT} will be used."
    emacs_src_url="${SRC_BASE_URL}-${REV_COMMIT}.tar.gz"
    emacs_src="emacs-${REV_COMMIT}"
else
    echo "Error! Please give a valid Git commit hash."
    exit 1
fi

emacs_src_tarball="${ROOT_DIR}/tarballs/${emacs_src}.tar.gz"
[[ -f "$emacs_src_tarball" ]] && rm "$emacs_src_tarball" && echo "Removed the ${emacs_src_tarball}"

echo "
Wget Will download source code from URL: ${emacs_src_url}
"
echo "Current directory is: " && pwd

# Enable proxy
[[ "$PROXY" = "ON" ]] && export https_proxy="http://127.0.0.1:8889"

echo "
Now using https proxy!
"

# Download the source code from Emacs repo
wget $emacs_src_url && echo "The ${emacs_src_tarball} have been download!"

# unzip

if [[ "$OSTYPE" =~ ^msys ]]; then
    TAR_CMD="/c/Windows/system32/tar.exe"
else
    TAR_CMD="tar"
fi


$TAR_CMD -xjf $emacs_src_tarball || echo "Ger error when tar -xjf ${emacs_src_tarball}"
echo "Unzipping ${emacs_src_tarball} suceeded!"

$TAR_CMD -xzf $emacs_src_tarball -C $BUILD_DIR && echo "tar source code to ${BUILD_DIR} finished."
cd "${BUILD_DIR}/${emacs_src}"
echo "Current directory is: " && pwd


SRC_DIR="${ROOT_DIR}/tarballs/${emacs_src}"

# Check the install directory for Windows build
if [[ "$OSTYPE" =~ ^msys ]]; then
    # If "$INSTALL_DIR" exit, remove it and create a new one
    [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR" && mkdir -p "$INSTALL_DIR"

    # if "$INSTALL_DIR" not exit, create a new one
    [[ -d "$INSTALL_DIR" ]] || mkdir -p "$INSTALL_DIR"
fi

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

# Use Clang for slightly faster builds
# See https://leeifrankjaw.github.io/articles/clang_vs_gcc_for_emacs.html
# See https://alibabatech.medium.com/gcc-vs-clang-llvm-an-in-depth-comparison-of-c-c-compilers-899ede2be378
# See https://docs.oracle.com/cd/E19957-01/806-3567/cc_options.html for CFLAG option explanations
# CFLAGS="-g -O2"
# export CC=clang
# export OBJC=clang


if [[ "$OSTYPE" =~ ^darwin ]]; then
    export LDFLAGS='-L/opt/local/lib -Wl,-headerpad_max_install_names -Wl'
    LDFLAGS+=',-rpath /opt/local/lib/gcc12 -Wl,-syslibroot'
    LDFLAGS+=',/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -arch x86_64'

    export LIBRARY_PATH='/opt/local/lib/gcc12:/opt/local/lib'
    export CPPFLAGS='-I/opt/local/include -isysroot/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk'
    export CPATH='/opt/local/include/gcc12:/opt/local/include'
else
    echo "No extra flags need to configure on current system."
fi


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
    ${NATIVE_COMP} \
    --without-dbus \

echo "
# ======================================================
# Build and install everything
# ======================================================
"

# Check number of processors & use as many as we can!
NCPU=$(expr $(getconf _NPROCESSORS_ONLN) / 2)

# Send output to log file using tee
# See https://stackoverflow.com/a/60432203/6277148

if [[ "$OSTYPE" =~ ^msys ]]; then
    make -j$NCPU | tee bootstrap-log.txt || exit 1 && make install -j$NCPU prefix=$INSTALL_DIR | tee build-log.txt
else
    make -j$NCPU | tee bootstrap-log.txt || exit 1 && make install -j$NCPU | tee build-log.txt

fi

echo "Build Emacs DONE!"

echo "
# ======================================================
# Delete old app & Move new app
# ======================================================
"

# Close any emacs sessions
[[ "$OSTYPE" =~ ^darwin ]] && pkill -i emacs


if [[ "$OSTYPE" =~ ^darwin ]]; then
    # Remove old emacs
    # See https://stackoverflow.com/a/677212/6277148
    # and https://stackoverflow.com/a/638980/6277148
    # for discussion of confitional checks for files
    if [ -e /Applications/Emacs.app ]; then
        if command -v trash </dev/null 2>&1; then
            echo "Trashing old emacs..."
            trash /Applications/Emacs.app
        else
            echo "Removing old emacs..."
            rm -rf /Applications/Emacs.app
        fi
    fi

    # Move build to applications folder
    mv ${BUILD_DIR}/${emacs_src}/nextstep/Emacs.app /Applications/Emacs.app

    echo "Move ${BUILD_DIR}/${emacs_src}/nextstep/Emacs.app to /Applications folder DONE!"


    echo "
# ======================================================
# Copy C Source Code
# ======================================================
"

    # Copy C source files to Emacs
    cp -r ${SRC_DIR}/src /Applications/Emacs.app/Contents/Resources/

    # Set emacs-repository-version and find-function-C-source-directory
    SITELISP="/Applications/Emacs.app/Contents/Resources/site-lisp"
    touch "./site-start.el" && echo "(setq emacs-repository-version \"${REV_COMMIT}\")" > "./site-start.el"
    echo "(setq find-function-C-source-directory \"/Applications/Emacs.app/Contents/Resources/src/\")" >> "./site-start.el"
    mv "./site-start.el" "${SITELISP}/" && echo "Moved site-start.el to ${SITELISP} directory."

    echo "DONE!"

elif [[ "$OSTYPE" =~ ^msys ]]; then
    echo "
# ======================================================
# Copy C Source Code
# ======================================================
"
    # Copy C source files to Emacs
    cp -r "${SRC_DIR}/src" "$INSTALL_DIR/"

    # Set emacs-repository-version and find-function-C-source-directory
    SITELISP="${INSTALL_DIR}/share/emacs/site-lisp"
    touch "./site-start.el" && echo "(setq emacs-repository-version \"${REV_COMMIT}\")" > "./site-start.el"
    echo "(setq find-function-C-source-directory \"c:/opt/emacs/src/\")" >> "./site-start.el"
    mv "./site-start.el" "${SITELISP}/" && echo "Moved site-start.el to ${SITELISP} directory."

    echo "DONE!"
fi



echo "
# ======================================================
# Create Log files
# ======================================================
"

# Make a directory for the build's log files and move them there
# Note that this removes a previous identical dir if making multiple similar builds


cur_dateTime="$(date +%Y-%m-%d)-T$(date +%H-%M-%S)"
echo "Current day is: $cur_dateTime"
mkdir -p ${ROOT_DIR}/build-logs/
mv "${BUILD_DIR}/${emacs_src}/config.log" "${ROOT_DIR}/build-logs/config-${cur_dateTime}.log"
mv "${BUILD_DIR}/${emacs_src}/build-log.txt" "${ROOT_DIR}/build-logs/build-log-${cur_dateTime}.txt"
mv "${BUILD_DIR}/${emacs_src}/bootstrap-log.txt" "${ROOT_DIR}/build-logs/bootstrap-log-${cur_dateTime}.txt"

echo "DONE!"

echo "
# ======================================================
# Cleanup
# ======================================================
"

# Delete src dir and build dir
rm -rf "${SRC_DIR}"
rm -rf "${BUILD_DIR}/${emacs_src}"

echo "DONE!"

echo "
# ======================================================
# Add executable to PATH
# ======================================================"

if [[ "$OSTYPE" =~ ^darwin ]]; then
    echo "
# Be sure to add /Applications/Emacs.app/Contents/MacOS/bin
# to your .zshrc or .profile PATH like so:
# export PATH=\$PATH:/Applications/Emacs.app/Contents/MacOS
# export PATH=\$PATH:/Applications/Emacs.app/Contents/MacOS/bin
"
    export PATH=$PATH:/Applications/Emacs.app/Contents/MacOS
    export PATH=$PATH:/Applications/Emacs.app/Contents/MacOS/bin

    echo "
execs added to this terminal session -- please
modify $HOME/.zshrc or $HOME/.zshenv accordingly
"
else
    echo "
# Please rename ${INSTALL_DIR} to C:\opt\emacs
# And add C:\opt\emacs\bin to your PATH
"
fi


END_DATE=$(date +"%s")
ELAPSED_TIME=$((END_DATE - START_DATE))

echo "Duration: $((ELAPSED_TIME / 3600))h: $((ELAPSED_TIME % 3600 / 60))m : $((ELAPSED_TIME % 60))s"
echo "Build script finished!"
