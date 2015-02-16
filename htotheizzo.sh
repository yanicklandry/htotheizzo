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

    # stop docker
    supervisorctl stop docker

    if [[ -d $docker_dir ]]; then
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
    fi

    # get the binary
    curl https://master.dockerproject.com/linux/amd64/docker > /usr/bin/docker

    # copy systemd config
    # replace_sysd

    supervisorctl start docker
}

update_linux() {
    apt-get -y update
    apt-get -y upgrade
    apt-get -y autoremove
    apt-get -y autoclean
    apt-get -y clean
    update_docker
}

update_homebrew() {
    brew update
    brew upgrade
    brew cleanup -s --force
    brew cask cleanup
}

update() {

    echo "htotheizzo is running the update functions"

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

    else
        echo "We don't have update functions for OS: ${OSTYPE}"
        echo "Moving on..."
    fi

    if command_exists gem; then
        echo "## Updating ruby gems..."
        gem update
        gem cleanup
    fi

    if command_exists npm-upgrade.sh; then
        echo "## Updating npm (safe way)..."
        npm-upgrade.sh

    elif command_exists npm; then
        echo "## Updating npm..."
        npm update -g
    fi

    if command_exists pip; then
        local pip_packages=`pip list -o | grep -v -i warning | cut -f1 -d' ' | tr  "\n|\r" " " | sed -e 's/^[ \t]*//'`
        echo "## Updating pip packages..."
        if [ ! -z "$pip_packages" ]; then
          for pip_package in "${pip_packages[@]}"; do
            echo "$pip_package"
              pip install --upgrade "${pip_package}"
          done
        else
          echo "no outdated packages found."
        fi
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
