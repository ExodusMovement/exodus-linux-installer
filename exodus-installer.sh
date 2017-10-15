#!/usr/bin/env bash
#
# Open source, released under the MIT license (see LICENSE file).
#
# https://www.gnu.org/software/bash/manual/bash.html
#
# Link this file so that `-eden` appears in the name, and the Eden version
# will be installed.
#

# Global variables
#
INSTALLER_VERSION=1.0.4
PROCESSOR="x64"
#
# Check for eden suffix in name of script. If detected, download the Eden version instead.
#
if [[ $0 =~ .*-eden.* ]]; then
  EDEN_DOWNLOAD_INFIX=-eden
  EDEN_BIN_SUFFIX=Eden
fi

if [ $EUID -ne 0 ]; then
  SUDO=sudo
fi

# Generate a base file name, with eden infix, processor and version.
#
exodus_filename() {
  echo 'exodus'${EDEN_DOWNLOAD_INFIX}'-linux-'${PROCESSOR}'-'$1'.zip'
}


# Generate the download URL
# This can change, so we have to make sure this is "up to date"
#
exodus_download_url() {
  echo 'https://exodusbin.azureedge.net/releases/'$1
}


# Generate the download target on disk
#
exodus_download_target() {
  mkdir -p $HOME/Downloads
  echo $HOME'/Downloads/'$1
}


# Download the Exodus payload from the server, but only
# download if we don't have it on disk already (-c option)
#
exodus_download() {
  wget -v -c -O $2 $1
}


# Download and check the exodus package to verify
# SHA hash. Shamelessly stolen from https://github.com/kklash/exodus_tools
exodus_verify_hashes() {
  #
  # If JP's key doesn't exist...
  if ! gpg -k | grep -q "JP Richardson" ; then 
    jpKey='https://keybase.io/jprichardson/pgp_keys.asc?fingerprint=12408650e2192febe4e7024c9d959455325b781a'
    # ...Import JP Richardson's Public Key
    curl -s $jpKey | gpg --import -q
  fi

  local HASHES=`exodus_download_url hashes-exodus${EDEN_DOWNLOAD_INFIX}-$1.txt`
  curl -s $HASHES | gpg --verify
  if ! [ $? -eq 0 ]; then
    return 1
  fi
  from_hash=`curl -s $HASHES | grep linux | perl -lane 'print $F[0]'`
  to_hash=`shasum -a 256 $2 | perl -lane 'print $F[0]'`
  test "$from_hash" == "$to_hash"
  return $?
}


# Install the exodus package to the /opt folder
#
exodus_install() {
  if [ "$SUDO" != "" ]; then
    echo "Running commands with SUDO..."
  fi

  # extract files & create link
  $SUDO unzip -d /opt/ $1
  $SUDO mv /opt/Exodus${EDEN_BIN_SUFFIX}-linux-* /opt/exodus${EDEN_DOWNLOAD_INFIX}
  $SUDO ln -s -f /opt/exodus${EDEN_DOWNLOAD_INFIX}/Exodus${EDEN_BIN_SUFFIX} /usr/bin/Exodus${EDEN_BIN_SUFFIX}

  # register exodus://
  $SUDO update-desktop-database > /dev/null 2>&1

  # update icons
  $SUDO gtk-update-icon-cache /usr/share/icons/hicolor -f > /dev/null 2>&1
}


# Check to see if Exodus is installed
#
exodus_is_installed() {
  which Exodus${EDEN_BIN_SUFFIX} > /dev/null 2>&1
}


# Uninstall the application completely
#
exodus_uninstall() {
  if [ "$SUDO" != "" ]; then
    echo "Running commands with SUDO..."
  fi

  # remove app files
  $SUDO rm -f /usr/bin/Exodus${EDEN_BIN_SUFFIX}
  $SUDO rm -rf /opt/exodus${EDEN_DOWNLOAD_INFIX}
  $SUDO rm -f /usr/share/applications/Exodus${EDEN_BIN_SUFFIX}.desktop
  $SUDO find /usr/share/icons/hicolor/ -type f -name *Exodus.png -delete

  # drop exodus://
  $SUDO update-desktop-database > /dev/null 2>&1

  # update icons
  $SUDO gtk-update-icon-cache /usr/share/icons/hicolor -f > /dev/null 2>&1
}


# Do the actual installation procedure, calling the above functions when needed.
#
# This function detects the command line arguments and verifies they are correct.
# Then each case is run according to the arguments. What this does is:
#
# 1) download the version specified from Exodus' servers (if version specified
#                                                         otherwise, use supplied filename)
# 2) check the integrity of the archive
# 3) check for root privileges (use sudo)
# 4) install the app
#
# Or, we can uninstall the app from the harddrive (root privs needed)
#
# Or, we can check to see if Exodus is installed.
#
exodus_installer() {
  if [ $# -lt 1 ]; then
    $0 --help
    return 0
  fi

  local COMMAND
  COMMAND=$1
  shift

  case $COMMAND in
    'help' | '--help' )
      cat << EOF

Exodus installer v$INSTALLER_VERSION

Usage:

  $0 --help                 Print this message
  $0 install <version|file> Install Exodus from file or download and install <version>
  $0 check                  Check that Exodus is installed and print installed version
  $0 uninstall              Remove Exodus

Example:

  $0 install ~/Downloads/exodus_linux_1.4.0.zip   Install Exodus 1.4.0 from file
  $0 install 1.4.0                                Download and install Exodus 1.4.0

EOF
    ;;
    'install' | 'i' )
      if [ $# -ne 1 ]; then
        >&2 $0 --help
        return 127
      fi

      if exodus_is_installed; then
        >&2 echo 'Exodus'${EDEN_BIN_SUFFIX}' already installed.'
        return 1
      fi

      local EXODUS_PKG
      if [[ $# -eq 1 && -f $1 ]]; then
        EXODUS_PKG=$1
      else
        local EXODUS_FILENAME=`exodus_filename $1`
        EXODUS_PKG=`exodus_download_target ${EXODUS_FILENAME}`
        local EXODUS_URL=`exodus_download_url ${EXODUS_FILENAME}`
        if ! exodus_download $EXODUS_URL $EXODUS_PKG; then
          return 1
        fi
      fi

      if ! exodus_verify_hashes $1 $EXODUS_PKG; then
        echo "$EXODUS_PKG has failed the hashing checksum! Aborting installation!"
        return 1
      fi

      if ! unzip -t $EXODUS_PKG > /dev/null; then
        echo "$EXODUS_PKG failed the SHA check, and is a corrupt file! Please remove and redownload!"
        return 1
      fi

      exodus_install $EXODUS_PKG
      return $?
    ;;
    'check' )
      if [ $# -ne 0 ]; then
        >&2 $0 --help
        return 127
      fi

      if exodus_is_installed; then
        echo 'Exodus'${EDEN_BIN_SUFFIX}' is installed. Version: '`Exodus${EDEN_BIN_SUFFIX} --version`
      else
        echo 'Exodus'${EDEN_BIN_SUFFIX}' is not installed.'
      fi
    ;;
    'uninstall' )
      if [ $# -ne 0 ]; then
        >&2 $0 --help
        return 127
      fi

      exodus_uninstall
      return $?
    ;;
    * )
      >&2 $0 --help
      return 127
    ;;
  esac
}


# pass arguments to main function
#
exodus_installer $@

# vim: ts=2 sw=2 et
