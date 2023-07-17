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
BUILD_DIR="${HOME}/tmp/emacs-build"
SRC_DIR="${HOME}/src/emacs"
GIT_VERSION="emacs-git-version.el"


if [[ "$OSTYPE" =~ ^darwin ]]; then
    RES_DIR="/Applications/Emacs.app/Contents/Resources"
    SITELISP="${RES_DIR}/site-lisp"
elif [[ "$OSTYPE" =~ ^msys ]]; then
    INSTALL_DIR="c:/opt/emacs"
    RES_DIR="${INSTALL_DIR}/share/emacs"
    SITELISP="${INSTALL_DIR}/share/emacs/site-lisp"

else
    echo "Not Support current system."
    exit 1
fi

# Native compilation
NATIVE_COMP="--without-native-compilation"

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

# Enable proxy
export https_proxy="http://127.0.0.1:8889" && echo "HTTPS proxy enabled."


echo "
# ======================================================
# Start with a clean build
# ======================================================
"

[[ -d "${BUILD_DIR}" ]] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

cd "${SRC_DIR}"
[[ -d "${SRC_DIR}" ]] || exit 1


# Check the install directory for Windows build
if [[ "$OSTYPE" =~ ^msys ]]; then
    [[ -d "$INSTALL_DIR" ]] && mv "$INSTALL_DIR" "${INSTALL_DIR}-$(date +%Y-%m-%d)"
    mkdir -p "$INSTALL_DIR"
fi


# ======================================================
# Input for version otherwise default to emacs-29 branch
# ======================================================

# Check for valid Git commit hash

if [[ "$1" =~ ^[a-zA-Z0-9]{7,40}$ ]]; then
    echo "Git commit hash is valid."
    commit="$1"
elif [[ -z "$1" ]] || [[ "$1" = "${NATIVE_COMP}" ]]; then
    echo "The latest Emacs master branch will be used."
    commit="origin/master"
    git checkout master
    git pull
elif [[ "$1" = "master" || "$1" = "emacs-29" ]]; then
    echo "The orgin/${1} will be used."
    commit="origin/${1}"
    git checkout "$1"
    git pull
else
    echo "Error! Please give a valid Git commit hash."
    exit 1
fi

[[ "$OSTYPE" =~ ^msys ]] && git config core.autocrlf false
git archive --format tar $commit | tar -C ${BUILD_DIR} -xf -

# ======================================================
# Set variables for git, time, & patches
# ======================================================

REV=`git log -n 1 --no-color --pretty='format:%h' ${commit}`
DAY=`git log -n 1 --no-color --pretty='format:%ai' ${commit}`
PATCH_LIST=`find ${ROOT_DIR}/patches/ -name '*.patch'`

cd ${BUILD_DIR} && echo "Current directory is: " && pwd

echo "
# ======================================================
# Apply Patches
# ======================================================
"

# Note that this applies all patches in 'patches' dir
for f in ${PATCH_LIST}; do
    echo "Applying patch `basename $f`"
    patch -p1 -i $f
done

# ======================================================
# Info settings
# ======================================================

if [[ "$OSTYPE" =~ ^darwin ]]; then
    # Here we set infofiles and variables for versioning
    STRINGS="
      nextstep/templates/Emacs.desktop.in
      nextstep/templates/Info-gnustep.plist.in
      nextstep/templates/Info.plist.in
      nextstep/templates/InfoPlist.strings.in"

    ORIG=`grep ^AC_INIT configure.ac`
    VNUM=`echo $ORIG | sed 's#^AC_INIT(\(.*\))#\1#; s/ //g' | cut -f2 -d,`
    VERS="$DAY Git $REV"
    DESCR="Emacs_Cocoa_${VNUM}_${DAY}_Git_${REV}"
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


# ======================================================
# Inscribe Version in Info files
# ======================================================

if [[ "$OSTYPE" =~ ^darwin ]]; then
    for f in $STRINGS; do
        sed -e "s/@version@/@version@ $VERS/" -i '' $f
    done
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
if [[ "$OSTYPE" =~ ^msys ]] && [[ ${NATIVE_COMP} =~ ^--with-native-compilation ]]; then
    echo "Warning: CFLAGS='-O2 -fno-optimize-sibling-calls'; see details: https://git.savannah.gnu.org/cgit/emacs.git/commit/?h=emacs-29&id=679e9d7c56e2296e3a218290d941e28002bf7722
"
    CFLAGS='-O2 -fno-optimize-sibling-calls' ./configure ${NATIVE_COMP} --without-dbus
else
    ./configure ${NATIVE_COMP} --without-dbus
fi

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
    mv ${BUILD_DIR}/nextstep/Emacs.app /Applications/Emacs.app

    echo "Move ${BUILD_DIR}/nextstep/Emacs.app to /Applications folder DONE!"
fi

echo "
# ======================================================
# Record Git SHA
# ======================================================
"

# This records the Git SHA to an elisp file and
# moves it to the site-lisp dir in the emacs build

cp ${ROOT_DIR}/materials/${GIT_VERSION} ${BUILD_DIR}/
sed -e "s/@@GIT_COMMIT@@/$REV/" -i '' ${BUILD_DIR}/${GIT_VERSION}
mv -f ${BUILD_DIR}/${GIT_VERSION} ${SITELISP}/${GIT_VERSION}

echo "(require 'emacs-git-version)" > "./site-start.el"

echo "DONE!"

echo "
# ======================================================
# Copy C Source Code
# ======================================================
"

# Copy C source files to Emacs
cp -r "${SRC_DIR}/src" "${RES_DIR}/"

# Help Emacs to find the coped SRC directory
echo "(setq find-function-C-source-directory \"${RES_DIR}/src/\")" >> "./site-start.el"
mv "./site-start.el" "${SITELISP}/" && echo "Moved site-start.el to ${SITELISP} directory."

echo "DONE!"

echo "
# ======================================================
# Change icon
# ======================================================
"

if [[ "$OSTYPE" =~ ^darwin ]]; then
    # Copy new icon to emacs (currently using a big sur icon)
    # See https://github.com/d12frosted/homebrew-emacs-plus/issues/419
    # cp "${ROOT_DIR}/materials/icons/emacs-big-sur.icns" "${RES_DIR}/Emacs.icns"
    cp "${ROOT_DIR}/materials/icons/savchenkovaleriy-big-sur.icns" "${RES_DIR}/Emacs.icns"

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

# Delete build dir
rm -rf "${BUILD_DIR}"

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
# And add c:\opt\emacs\bin to your PATH
"
fi


END_DATE=$(date +"%s")
ELAPSED_TIME=$((END_DATE - START_DATE))

echo "Duration: $((ELAPSED_TIME / 3600))h: $((ELAPSED_TIME % 3600 / 60))m : $((ELAPSED_TIME % 60))s"
echo "Build script finished!"
