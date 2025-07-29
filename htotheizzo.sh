#!/bin/bash

set -euo pipefail

THISUSER=$(who am i | awk '{print $1}')

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

log "Running as $THISUSER."

help() {
  echo "htotheizzo - a simple script that makes updating/upgrading homebrew or apt-get, gems, pip packages, and node packages so much easier"
}

command_exists() {
  local cmd="$1"
  local varname="skip_${cmd}"
  local skip_var="${!varname:-}"

  if [[ -n "${skip_var}" ]]; then
    log "Skipped $cmd"
    return 1
  fi

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "Command $cmd not found"
    return 1
  fi

  return 0
}

replace_sysd() {
  if [[ -d /home/$THISUSER/.sysd ]]; then
    yes | cp -rf /home/$THISUSER/.sysd/* /lib/systemd/system/
    systemctl daemon-reload
    service docker start
  fi
}


update_linux() {
  log "Starting Linux updates..."
  
  # Test sudo access
  if ! sudo -n true 2>/dev/null; then
    log "Requesting sudo access..."
    sudo echo "Got sudo."
  fi
  
  update_apt
  update_docker
  update_snap
  update_flatpak
  update_bun
  clean_logs
  
  if command_exists brew; then
    log "Updating Homebrew..."
    update_homebrew
  fi
}

update_apt() {
  log "Updating apt packages..."
  export DEBIAN_FRONTEND=noninteractive
  
  local apt_commands=(
    "sudo apt -y update"
    "sudo apt -y upgrade"
    "sudo apt -y dist-upgrade"
    "sudo apt -y autoremove"
    "sudo apt -y autoclean"
    "sudo apt -y clean"
    "sudo apt-get autoremove --purge -y"
  )
  
  for cmd in "${apt_commands[@]}"; do
    if ! eval "$cmd"; then
      log "Warning: '$cmd' failed"
    fi
  done
  
  # Clean up package lists
  sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true
}

update_snap() {
  if command_exists snap; then
    log "Updating Snap packages..."
    sudo snap refresh || log "Warning: snap refresh failed"
    
    log "Clearing old Snaps"
    # Safer approach to removing disabled snaps
    local disabled_snaps
    disabled_snaps=$(snap list --all | awk '/disabled/{print $1, $3}' | sort -u)
    
    if [[ -n "$disabled_snaps" ]]; then
      echo "$disabled_snaps" | while read -r snapname revision; do
        if [[ -n "$snapname" && -n "$revision" ]]; then
          sudo snap remove "$snapname" --revision="$revision" || log "Warning: failed to remove $snapname revision $revision"
        fi
      done
    fi
  fi
}

update_flatpak() {
  if command_exists flatpak; then
    log "Updating Flatpak packages..."
    sudo flatpak update -y || log "Warning: flatpak update failed"
    sudo flatpak uninstall --unused -y || log "Warning: flatpak cleanup failed"
  fi
}

update_bun() {
  if command_exists bun; then
    log "Updating Bun..."
    bun upgrade || log "Warning: bun upgrade failed"
  fi
}

clean_logs() {
  if command_exists journalctl; then
    log "Cleaning logs using journalctl..."
    sudo journalctl --vacuum-time=3d || log "Warning: journalctl cleanup failed"
  fi
}

update_vscode_ext() {
  if command_exists code; then
    log "Updating VS Code Extensions..."
    code --update-extensions || log "Warning: VS Code extension update failed"
  fi
}

update_homebrew() {
  log "Updating Homebrew..."
  brew update || log "Warning: brew update failed"
  brew upgrade || log "Warning: brew upgrade failed"
  brew cleanup -s || log "Warning: brew cleanup failed"
}

update_homebrew_with_casks() {
  log "Updating Homebrew with casks..."
  brew update || log "Warning: brew update failed"
  brew outdated --greedy || log "Warning: brew outdated failed"
  brew upgrade || log "Warning: brew upgrade failed"
  brew upgrade --cask --greedy || log "Warning: brew cask upgrade failed"
  brew cleanup -s || log "Warning: brew cleanup failed"
}

mac_disk_maintenance() {
  log "Performing disk maintenance..."
  
  # Verify disk integrity
  sudo diskutil verifyVolume / || log "Warning: disk verification failed"
  
  # Clear memory caches
  log "Clearing memory caches..."
  sudo purge || log "Warning: memory purge failed"
  
  # Clear user caches
  log "Clearing user caches..."
  if [[ -d ~/Library/Caches ]]; then
    local cache_size
    cache_size=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1 || echo "unknown")
    log "User cache size: $cache_size"
    find ~/Library/Caches -type f -delete 2>/dev/null || log "Warning: cache cleanup failed"
  fi
}

mac_system_maintenance() {
  log "Running system maintenance scripts..."
  
  # Run periodic maintenance scripts
  sudo periodic daily weekly monthly || log "Warning: periodic maintenance failed"
  
  # Flush DNS cache
  log "Flushing DNS cache..."
  sudo dscacheutil -flushcache || log "Warning: DNS cache flush failed"
  sudo killall -HUP mDNSResponder 2>/dev/null || log "Warning: mDNSResponder restart failed"
}

mac_spotlight_rebuild() {
  log "Rebuilding Spotlight index..."
  sudo mdutil -E / || log "Warning: Spotlight rebuild failed"
}

mac_reset_launchpad() {
  log "Resetting Launchpad..."
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock 2>/dev/null || log "Warning: Dock restart failed"
}

update_itself() {
  log "Updating htotheizzo itself..."
  local ourpwd="$PWD"
  local file="${BASH_SOURCE[0]}"
  local dir link realpath
  
  # Handle symlinks properly
  if [[ -L "$file" ]]; then
    log "Following symlink to find real script location..."
    cd "$(dirname "$file")" || { log "Warning: failed to cd to script directory"; return 1; }
    link=$(readlink "$(basename "$file")")
    
    while [[ -n "$link" ]]; do
      if [[ "$link" = /* ]]; then
        # Absolute path
        cd "$(dirname "$link")" || { log "Warning: failed to follow symlink"; return 1; }
      else
        # Relative path
        cd "$(dirname "$link")" || { log "Warning: failed to follow symlink"; return 1; }
      fi
      link=$(readlink "$(basename "$link")" 2>/dev/null || echo "")
    done
    
    realpath="$PWD/$(basename "$file")"
    cd "$ourpwd" || { log "Warning: failed to return to original directory"; return 1; }
    dir="$(cd -P "$(dirname "$realpath")" && pwd)" || { log "Warning: failed to resolve real directory"; return 1; }
  else
    # Not a symlink, use direct path
    dir="$(cd -P "$(dirname "$file")" && pwd)" || { log "Warning: failed to resolve script directory"; return 1; }
  fi
  
  log "Changing to git repository directory: $dir"
  cd "$dir" || { log "Warning: failed to change to git directory"; return 1; }
  
  # Check if we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log "Warning: not in a git repository, skipping self-update"
    cd "$ourpwd" || true
    return 1
  fi
  
  log "Running git pull..."
  if git pull; then
    log "Successfully updated htotheizzo"
  else
    log "Warning: git pull failed"
  fi
  
  cd "$ourpwd" || log "Warning: failed to return to original directory"
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
    log "Hey there Mac user. At least it's not Windows."

    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
      log "Requesting sudo access..."
      sudo echo "Got sudo."
    fi

    # Install Apple Command Line Tools (necessary after an update)
    if command_exists xcode-select; then
      log "Updating Apple Command Line Tools..."
      sudo xcodebuild -license accept 2>/dev/null || log "Warning: xcodebuild license accept failed"
      xcode-select --install 2>/dev/null || log "Command line tools already installed or installation failed"
    fi

    if command_exists brew; then
      log "Updating Homebrew..."
      update_homebrew_with_casks
    fi

    if command_exists softwareupdate; then
      log "Updating Apple Software Update"
      softwareupdate --install --all || log "Warning: softwareupdate failed"
    fi

    # Update Mac App Store using : https://github.com/argon/mas
    if command_exists mas; then
      log "Updating Mac App Store..."
      mas upgrade || log "Warning: mas upgrade failed"
    fi

    # Update Microsoft Office
    if [ -d "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app" ]; then
      log "Opening Microsoft AutoUpdate..."
      open "/Library/Application Support/Microsoft/MAU2.0/Microsoft AutoUpdate.app" || log "Warning: failed to open Microsoft AutoUpdate"
    fi

    # Run macOS maintenance tasks
    mac_disk_maintenance
    mac_system_maintenance
    
    # Optional maintenance (can be skipped with environment variables)
    if [[ -z "${skip_spotlight:-}" ]]; then
      mac_spotlight_rebuild
    fi
    
    if [[ -z "${skip_launchpad:-}" ]]; then
      mac_reset_launchpad
    fi

  elif [[ -n "$is_raspberry" ]]; then
    log "Hello Raspberry Pi."
    # on linux, make sure they are the super user
    if [ "$UID" -ne 0 ]; then
      log "Please run as root"
      exit 1
    fi

    # update
    update_linux
    if command_exists rpi-update; then
      rpi-update || log "Warning: rpi-update failed"
    fi

  else
    echo "We don't have update functions for OS: ${OSTYPE}"
    echo "Moving on..."
  fi

  sudo echo "Kept sudo."

  update_itself

  update_vscode_ext

  if command_exists kav; then
    log "Updating Kaspersky Security Tools..."
    kav update || log "Warning: kav update failed"
  fi

  if command_exists omz; then
    log "Updating Oh My ZSH..."
    omz update || log "Warning: omz update failed"
  fi

  if command_exists apm; then
    log "Updating Atom packages (apm)..."
    apm update --no-confirm || log "Warning: apm update failed"
  fi

  if command_exists npm; then
    log "Updating npm..."
    npm install -g npm || log "Warning: npm self-update failed"
    
    log "Updating npm global packages..."
    # Get list of outdated global packages and update them
    local outdated_packages
    outdated_packages=$(npm outdated -g --depth=0 --json 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "")
    
    if [[ -n "$outdated_packages" ]]; then
      echo "$outdated_packages" | while read -r package; do
        if [[ -n "$package" ]]; then
          log "Updating global package: $package"
          npm install -g "$package@latest" || log "Warning: failed to update $package"
        fi
      done
    else
      # Fallback method if jq is not available
      log "Checking for outdated global packages..."
      npm update -g || log "Warning: npm global update failed"
    fi
    
    npm cache clean --force || log "Warning: npm cache clean failed"
  fi

  if command_exists yarn; then
    log "Updating yarn..."
    local yarn_path
    yarn_path=$(which yarn)
    
    if [[ "$yarn_path" == *"homebrew"* ]]; then
      log "Yarn installed via Homebrew, updating through brew"
      # Yarn will be updated when Homebrew updates
      log "Yarn will be updated with Homebrew packages"
    elif [[ "$yarn_path" == *"corepack"* ]] || [[ -x "$(command -v corepack)" ]]; then
      log "Yarn installed via corepack, enabling latest version"
      corepack enable || log "Warning: corepack enable failed"
      corepack prepare yarn@stable --activate || log "Warning: corepack yarn update failed"
    elif command_exists npm; then
      log "Attempting yarn update via npm..."
      npm install -g yarn --force || log "Warning: yarn update via npm failed"
    else
      log "Warning: Skipping yarn update - no safe update method available"
    fi
  fi

  if command_exists nvm; then
    nvm install stable
    nvm use stable
    nvm alias default stable
  fi

  if command_exists pip; then
    log "Updating pip packages..."
    export PIP_REQUIRE_VIRTUALENV=false
    pip install --upgrade pip --user || log "Warning: pip self-update failed"
    
    # Update user packages more safely
    local pip_packages
    pip_packages=$(pip freeze --user | cut -d'=' -f1 2>/dev/null || echo "")
    if [[ -n "$pip_packages" ]]; then
      echo "$pip_packages" | xargs -n1 pip install -U --user || log "Warning: pip package updates failed"
    fi
    export PIP_REQUIRE_VIRTUALENV=true
  fi

  if command_exists pip3; then
    log "Updating pip3 packages..."
    export PIP_REQUIRE_VIRTUALENV=false
    python3 -m pip install --upgrade pip --user || log "Warning: pip3 self-update failed"
    
    # Update user packages more safely
    local pip3_packages
    pip3_packages=$(pip3 freeze --user | cut -d'=' -f1 2>/dev/null || echo "")
    if [[ -n "$pip3_packages" ]]; then
      echo "$pip3_packages" | xargs -n1 pip3 install -U --user || log "Warning: pip3 package updates failed"
    fi
    export PIP_REQUIRE_VIRTUALENV=true
  fi

  if command_exists pipenv; then
    # echo "Clearing pipenv cache"
    pipenv --clear
  fi

  if command_exists rvm; then
    log "Updating rvm"
    rvm get stable || log "Warning: rvm update failed"
    rvm cleanup all || log "Warning: rvm cleanup failed"
  fi

  sudo echo "Kept sudo."

  if command_exists gem; then
    log "Updating ruby gems..."
    sudo gem update || log "Warning: gem update failed"
    sudo gem cleanup || log "Warning: gem cleanup failed"
  fi

  if [[ -d tmp ]]; then
    rm -rf tmp
  fi

  log "htotheizzo is complete, you got 99 problems but updates ain't one"
}

main() {
  local arg="${1:-}"
  if [[ -n "$arg" ]]; then
    help
  else
    update
  fi
}

main "$@"
