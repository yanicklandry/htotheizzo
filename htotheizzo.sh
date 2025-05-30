#!/bin/bash

THISUSER=$(who am i | awk '{print $1}')

echo "Running as $THISUSER."

help() {
  echo "htotheizzo - a simple script that makes updating/upgrading homebrew or apt-get, gems, pip packages, and node packages so much easier"
}

command_exists() {

  varname="skip_$@"
  SKIP_CMD_VAR="${!varname}"

  if [[ -z "${SKIP_CMD_VAR}" ]]; then
    echo ""
  else
    echo "Skipped $@"
    return 1
  fi

  command -v "$@" >/dev/null 2>&1
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
        gzip -c "$manFile" >"$manRoot/$manBase/$manName.gz"
      done
    done

    # move vim syntax highlighting
    if [[ -d /home/$THISUSER/.vim/bundle/Dockerfile ]]; then
      rm -rf /home/$THISUSER/.vim/bundle/Dockerfile
    fi
    yes | cp -rf contrib/syntax/vim /home/$THISUSER/.vim/bundle/Dockerfile
    chown -R $THISUSER /home/$THISUSER/.vim/bundle/Dockerfile

    # get the binary
    curl https://master.dockerproject.com/linux/amd64/docker >/usr/bin/docker

    # copy systemd config
    # replace_sysd

    supervisorctl start docker
  fi

}

update_linux() {
  sudo echo "Got sudo."
  update_apt
  update_docker
  update_snap
  update_flatpak
  update_bun
  clean_logs
  if command_exists brew; then
    echo "## Updating Home Brew..."
    update_homebrew
  fi
}

update_apt() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt -y update
  sudo apt -y upgrade
  sudo apt -y dist-upgrade
  sudo apt -y autoremove
  sudo apt -y autoclean
  sudo apt -y clean
  sudo apt-get purge -y
  sudo apt-get autoremove --purge -y
  sudo rm -rf /var/lib/apt/lists/*
}

update_snap() {
  if command_exists snap; then
    echo "## Updating Snap packages..."
    sudo snap refresh
    echo "## Clearing old Snaps"
    sudo snap remove --purge $(snap list --all | awk '/^disabled/{print $1}')

    LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
      while read snapname revision; do
        sudo snap remove "$snapname" --revision="$revision"
      done
  fi
}

update_flatpak() {
  echo "## Updating Flatpack..."
  if command_exists flatpak; then
    sudo flatpak update -y
    sudo flatpak uninstall --unused -y
  fi
}

update_bun() {
  echo "## Updating Bun..."
  if command_exists bun; then
    bun upgrade
  fi
}

clean_logs() {
  echo "## Cleaning logs using journalctl..."
  sudo journalctl --vacuum-time=3d
}

update_vscode_ext() {
  if command_exists code; then
    echo "## Updating VS Code Extensions..."
    code --update-extensions
  fi
}

update_homebrew() {
  brew update
  brew upgrade
  brew cleanup -s
}

update_homebrew_with_casks() {
  brew update
  brew outdated --greedy
  brew upgrade
  brew upgrade --cask --greedy
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
  DIR="$(cd -P "$(dirname "$REALPATH")" && pwd)"
  cd $DIR
  git pull
}

update() {

  echo "htotheizzo is running the update functions"

  local is_raspberry=$(uname -a | grep raspberrypi)

  # detect the OS for the update functions
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    echo "Hey there Linux user. You rule."

    # update
    update_linux

  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Hey there Mac user. At least it's not Windows."

    sudo echo "Kept sudo."

    # Install Apple Command Line Tools (necessary after an update)
    if command_exists xcode-select; then
      echo "## Updating Apple Command Line Tools..."
      sudo xcodebuild -license accept
      xcode-select --install
    fi

    if command_exists brew; then
      echo "## Updating Home Brew..."
      update_homebrew_with_casks
    fi

    sudo echo "Kept sudo."

    if command_exists softwareupdate; then
      echo "## Updating Apple Software Update"
      softwareupdate --install --all
    fi

    sudo echo "Kept sudo."

    # Update Mac App Store using : https://github.com/argon/mas
    if command_exists mas; then
      echo "## Updating Mac App Store..."
      mas upgrade
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
    update_linux
    rpi-update

  else
    echo "We don't have update functions for OS: ${OSTYPE}"
    echo "Moving on..."
  fi

  sudo echo "Kept sudo."

  update_itself

  update_vscode_ext

  if command_exists kav; then
    echo "## Updating Kaspersky Security Tools..."
    kav update
  fi

  if command_exists omz; then
    echo "## Updating Oh My ZSH..."
    omz update
  fi

  if command_exists apm; then
    echo "## Updating Atom packages (apm)..."
    apm update --no-confirm
  fi

  if command_exists npm; then
    echo "## Updating npm..."
    npm install -g npm
    npx npm-check --global --update-all
    npm cache clean --force
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
    pip install --upgrade pip --user
    pip freeze --user | cut -d'=' -f1 | xargs -n1 pip install -U
    export PIP_REQUIRE_VIRTUALENV=true
  fi

  if command_exists pip3; then
    # echo "Updating pip3 tool itself"
    export PIP_REQUIRE_VIRTUALENV=false
    python3 -m pip install --upgrade pip --user
    pip3 freeze --user | cut -d'=' -f1 | xargs -n1 pip3 install -U
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

  sudo echo "Kept sudo."

  if command_exists gem; then
    echo "## Updating ruby gems..."
    sudo gem update
    sudo gem cleanup
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
