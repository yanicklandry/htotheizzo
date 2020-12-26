#!/bin/bash

THISUSER=`whoami`

help() {
  echo "htotheizzo - a simple script that makes updating/upgrading homebrew or apt-get, gems, pip packages, and node packages so much easier"
}

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

replace_sysd() {
  if [[ -d /home/$THISUSER/.sysd ]]; then
    yes | cp -rf /home/$THISUSER/.sysd/* /lib/systemd/system/
    systemctl daemon-reload
    service docker start
  fi
}

update_docker() {
  local docker_dir="/home/$THISUSER/Repos/docker/docker"

  if [[ -d $docker_dir ]]; then
    # stop docker
    supervisorctl stop docker

    cd $docker_dir

    # Include contributed completions
    mkdir -p /etc/bash_completion.d
    cp contrib/completion/bash/docker /etc/bash_completion.d/

    # Include contributed man pages
    docs/man/md2man-all.sh -q
    local manRoot="/usr/share/man"
    mkdir -p "$manRoot"
    for manDir in docs/man/man?; do
      local manBase="$(basename "$manDir")" # "man1"
      for manFile in "$manDir"/*; do
        local manName="$(basename "$manFile")" # "docker-build.1"
        mkdir -p "$manRoot/$manBase"
        gzip -c "$manFile" > "$manRoot/$manBase/$manName.gz"
      done
    done

    # move vim syntax highlighting
    if [[ -d /home/$THISUSER/.vim/bundle/Dockerfile ]]; then
      rm -rf /home/$THISUSER/.vim/bundle/Dockerfile
    fi
    yes | cp -rf contrib/syntax/vim /home/$THISUSER/.vim/bundle/Dockerfile
    chown -R $THISUSER /home/$THISUSER/.vim/bundle/Dockerfile

    # get the binary
    curl https://master.dockerproject.com/linux/amd64/docker > /usr/bin/docker

    # copy systemd config
    # replace_sysd

    supervisorctl start docker
  fi

}

update_linux() {
  DEBIAN_FRONTEND=noninteractive apt-get -y update
  DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
  DEBIAN_FRONTEND=noninteractive apt-get -y autoremove
  DEBIAN_FRONTEND=noninteractive apt-get -y autoclean
  DEBIAN_FRONTEND=noninteractive apt-get -y clean
  update_docker
  update_homebrew
}

update_homebrew() {
  brew update
  brew upgrade
  brew cask reinstall `brew outdated --cask`
  brew cleanup -s
}

update_itself() {
  echo "## Updating htotheizzo itself..."
  OURPWD=$PWD
  FILE="${BASH_SOURCE[0]}"
  cd "$(dirname "$FILE")"
  LINK=$(readlink "$(basename "$FILE")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$FILE")")
  done
  REALPATH="$PWD/$(basename "$FILE")"
  cd "$OURPWD"
  DIR="$( cd -P "$( dirname "$REALPATH" )" && pwd )"
  cd $DIR
  git pull
}

update() {

  echo "htotheizzo is running the update functions"

  local is_raspberry=`uname -a | grep raspberrypi`;

  update_itself;

  # detect the OS for the update functions
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    echo "Hey there Linux user. You rule."

    # on linux, make sure they are the super user
    if [ "$UID" -ne 0 ]; then
      echo "Please run as root"
      exit 1
    fi

    # update
    update_linux;

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Hey there Mac user. At least it's not Windows."

    # update
    echo "## Updating Homebrew..."
    update_homebrew;

    # Update Mac App Store using : https://github.com/argon/mas
    if command_exists mas; then
      echo "## Updating Mac App Store..."
      mas upgrade;
    fi

    # Update Microsoft Office
    if [ -d /Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app ]; then
      open /Library/Application\ Support/Microsoft/MAU2.0/Microsoft\ AutoUpdate.app
    fi

  elif [[ is_raspberry ]]; then
    echo "Hello Raspberry Pi."
    # on linux, make sure they are the super user
    if [ "$UID" -ne 0 ]; then
      echo "Please run as root"
      exit 1
    fi

    # update
    update_linux;
    rpi-update;

  else
    echo "We don't have update functions for OS: ${OSTYPE}"
    echo "Moving on..."
  fi

  if command_exists upgrade_oh_my_zsh; then
    echo "## Updating Oh My ZSH..."
    upgrade_oh_my_zsh
  fi

  if command_exists apm; then
    echo "## Updating Atom packages (apm)..."
    apm update --no-confirm
  fi

  if command_exists npm; then
    echo "## Updating npm..."
    npm update -g
  fi

  if command_exists yarn; then
    echo "## Updating yarn..."
    curl -o- -L https://yarnpkg.com/install.sh | bash
  fi

  if command_exists nvm; then
    nvm install stable
    nvm use stable
    nvm alias default stable
  fi

  if command_exists pip; then
    echo "Updating pip tool itself"
    export PIP_REQUIRE_VIRTUALENV=false
    pip install --upgrade pip
    local pip_packages=`pip list -o --trusted-host mirrors.aliyun.com | grep -v -i -E "warning|Could not|--allow-" | cut -f1 -d' ' | sed -e 's/^[ \t]*//'`
    echo "## Updating pip packages..."
    if [ ! -z "$pip_packages" ]; then
      echo "$pip_packages" | while read pip_package; do
        echo "## Upgrading $pip_package..."
        pip install --upgrade "${pip_package}"
      done
    else
      echo "no outdated packages found."
    fi
    export PIP_REQUIRE_VIRTUALENV=true
  fi

  if command_exists pip3; then
    # echo "Updating pip3 tool itself"
    export PIP_REQUIRE_VIRTUALENV=false
    # pip3 install --upgrade pip3
    local pip3_packages=`pip3 list -o --trusted-host mirrors.aliyun.com | grep -v -i -E "warning|Could not|--allow-" | cut -f1 -d' ' | sed -e 's/^[ \t]*//'`
    echo "## Updating pip3 packages..."
    if [ ! -z "$pip3_packages" ]; then
      echo "$pip3_packages" | while read pip3_package; do
        echo "## Upgrading $pip3_package..."
        pip3 install --upgrade "${pip3_package}"
      done
    else
      echo "no outdated packages found."
    fi
    export PIP_REQUIRE_VIRTUALENV=true
  fi

  if command_exists pipenv; then
    # echo "Clearing pipenv cache"
    pipenv --clear
  fi

  if command_exists rvm; then
    echo "## Updating rvm"
    rvm get stable
    rvm cleanup all
  fi

  if command_exists softwareupdate; then
    echo "## Updating Apple Software Update"
    softwareupdate --install --all
  fi

  if command_exists gem; then
    echo "## Updating ruby gems..."
    sudo gem update
    sudo gem cleanup
  fi

  if command_exists snap; then
    echo "## Updating Snap packages..."
    snap refresh
    echo "## Clearing old Snaps"
    set -eu

    LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
        while read snapname revision; do
            snap remove "$snapname" --revision="$revision"
        done
  fi

  if [[ -d tmp ]]; then
    rm -rf tmp
  fi

  echo "htotheizzo is complete, you got 99 problems but updates ain't one"
}

main() {
  local arg=$1
  if [[ ! -z "$arg" ]]; then
    help
  else
    update
  fi
}

main $@
