#!/usr/bin/env bash

# https://www.gnu.org/software/bash/manual/bash.html
INSTALLER_VERSION=1.0.3

exodus_download_url() {
  echo 'https://exodusbin.azureedge.net/releases/exodus-linux-x64-'$1'.zip'
}

exodus_download_target() {
  echo $HOME'/Downloads/exodus_linux_'$1'.zip'
}

exodus_download() {
  if [ -e $2 ];
  then
    echo $2' already exists, overwrite it?'
    select yn in 'Yes' 'No'; do
      case $yn in
        'Yes' )
          wget -v -O $2 $1
          break
        ;;
        'No' )
          break
        ;;
      esac
    done
  else
	wget -v -O $2 $1
  fi 
}

exodus_install() {
  # extract files & create link
  #xz -dkfc $1 | tar -x -C /
  unzip -d /opt/ $1
  mv /opt/Exodus-linux-* /opt/exodus
  ln -s -f /opt/exodus/Exodus /usr/bin/Exodus

  # register exodus://
  update-desktop-database > /dev/null 2>&1

  # update icons
  gtk-update-icon-cache /usr/share/icons/hicolor -f > /dev/null 2>&1
}

exodus_is_installed() {
  which Exodus > /dev/null 2>&1
}

exodus_uninstall() {
  # remove app files
  rm -f  /usr/bin/Exodus
  rm -rf /opt/exodus
  rm -f  /usr/share/applications/Exodus.desktop
  find /usr/share/icons/hicolor/ -type f -name *Exodus.png -delete

  # drop exodus://
  update-desktop-database > /dev/null 2>&1

  # update icons
  gtk-update-icon-cache /usr/share/icons/hicolor -f > /dev/null 2>&1
}

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

      exodus_is_installed
      if [ $? -eq 0 ]; then
        >&2 echo 'Exodus already installed.'
        return 1
      fi

      local EXODUS_PKG
      if [[ $# -eq 1 && -f $1 ]]; then
        EXODUS_PKG=$1
      else
        EXODUS_PKG=`exodus_download_target $1`
        exodus_download `exodus_download_url $1` $EXODUS_PKG
      fi

      unzip -t $EXODUS_PKG
      if [ $? -ne 0 ]; then
        return 1
      fi

      if [ $EUID -ne 0 ]; then
        >&2 echo 'Root privileges required...'
        >&2 echo '  sudo' $0 'install' $@
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

      exodus_is_installed
      if [ $? -eq 1 ]; then
        echo 'Exodus is not installed.'
      else
        echo 'Exodus is installed. Version: '`Exodus --version`
      fi
    ;;
    'uninstall' )
      if [ $# -ne 0 ]; then
        >&2 $0 --help
        return 127
      fi

      if [ $EUID -ne 0 ]; then
        >&2 echo 'Root privileges required...'
        >&2 echo '  sudo' $0 'install' $@
        return 1
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
exodus_installer $@

# vim: ts=4 sw=2
