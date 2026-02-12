#!/bin/bash

set -euo pipefail

THISUSER=$(who am i | awk '{print $1}')

# Mock mode - if set, commands will be logged but not executed
MOCK_MODE="${MOCK_MODE:-}"

# Error tracking array
declare -a ERROR_LOG=()

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2

    # Track warnings and errors
    if [[ "$1" == Warning:* ]] || [[ "$1" == Error:* ]]; then
        ERROR_LOG+=("$1")
    fi
}

# Display error summary at the end
show_error_summary() {
    local error_count=${#ERROR_LOG[@]}

    if [[ $error_count -eq 0 ]]; then
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        log "✓ All updates completed successfully with no errors!"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
    else
        echo ""
        echo "════════════════════════════════════════════════════════════════"
        log "⚠ Updates completed with $error_count warning(s)/error(s):"
        echo "════════════════════════════════════════════════════════════════"

        local counter=1
        for error in "${ERROR_LOG[@]}"; do
            echo "  $counter. $error" >&2
            ((counter++))
        done

        echo "════════════════════════════════════════════════════════════════"
        echo ""
    fi
}

# Execute command or mock it
maybe_run() {
    local cmd="$1"
    if [[ -n "$MOCK_MODE" ]]; then
        log "[MOCK] Would run: $cmd"
        return 0
    else
        eval "$cmd"
    fi
}

# Standardized error handling helper
run_with_fallback() {
  local cmd="$1"
  local description="$2"
  local silent="${3:-false}"
  
  if [[ "$silent" == "true" ]]; then
    if ! eval "$cmd" >/dev/null 2>&1; then
      log "Warning: $description failed"
      return 1
    fi
  else
    if ! eval "$cmd"; then
      log "Warning: $description failed"
      return 1
    fi
  fi
  return 0
}

log "Running as $THISUSER."

help() {
  echo "htotheizzo - a simple script that makes updating/upgrading homebrew or apt-get, gems, pip packages, and node packages so much easier"
}

command_exists() {
  local cmd="$1"
  # Normalize variable name by replacing hyphens with underscores
  local normalized_cmd="${cmd//-/_}"
  local varname="skip_${normalized_cmd}"
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
  
  # Execute apt commands directly instead of using eval
  sudo apt -y update || log "Warning: 'apt update' failed"
  sudo apt -y upgrade || log "Warning: 'apt upgrade' failed"
  sudo apt -y dist-upgrade || log "Warning: 'apt dist-upgrade' failed"
  sudo apt -y autoremove || log "Warning: 'apt autoremove' failed"
  sudo apt -y autoclean || log "Warning: 'apt autoclean' failed"
  sudo apt -y clean || log "Warning: 'apt clean' failed"
  sudo apt-get autoremove --purge -y || log "Warning: 'apt-get autoremove --purge' failed"
  
  # Clean up package lists
  run_with_fallback "sudo rm -rf /var/lib/apt/lists/*" "package lists cleanup" true
}

update_snap() {
  if command_exists snap; then
    log "Updating Snap packages..."
    sudo snap refresh || log "Warning: snap refresh failed"
    
    log "Clearing old Snaps"
    # Safer approach to removing disabled snaps
    local disabled_snaps
    if ! disabled_snaps=$(snap list --all 2>/dev/null | awk '/disabled/{print $1, $3}' | sort -u); then
      log "Warning: Failed to get disabled snaps list"
      return 1
    fi
    
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
  local with_casks="${1:-false}"

  if [[ "$with_casks" == "true" ]]; then
    log "Updating Homebrew with casks..."
  else
    log "Updating Homebrew..."
  fi

  # Note: brew upgrade automatically runs brew update first (since Homebrew 1.0)
  if [[ "$with_casks" == "true" ]]; then
    brew outdated --greedy || log "Warning: brew outdated failed"

    # Capture cask upgrade errors with details
    local cask_output
    local cask_exit_code=0
    cask_output=$(brew upgrade --cask --greedy 2>&1) || cask_exit_code=$?

    if [[ $cask_exit_code -ne 0 ]]; then
      # Extract failed cask names from error output
      local failed_casks=$(echo "$cask_output" | grep -oE "Cask '[^']+'" | sed "s/Cask '//" | sed "s/'$//" | tr '\n' ', ' | sed 's/,$//')
      if [[ -n "$failed_casks" ]]; then
        log "Warning: brew cask upgrade failed for: $failed_casks"
      else
        log "Warning: brew cask upgrade failed"
      fi
    fi
  fi

  brew upgrade || log "Warning: brew upgrade failed"
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
    if ! cache_size=$(du -sh ~/Library/Caches 2>/dev/null | cut -f1); then
      cache_size="unknown"
    fi
    log "User cache size: $cache_size"
    # More selective cache cleanup - only clear specific safe directories
    # Combine find operations into one command for better performance
    log "Removing temporary cache files (this may take a while for large caches)..."
    # Use timeout to prevent indefinite hanging (max 5 minutes)
    if command -v gtimeout >/dev/null 2>&1; then
      gtimeout 300 find ~/Library/Caches \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || log "Warning: cache cleanup timed out or failed"
    elif command -v timeout >/dev/null 2>&1; then
      timeout 300 find ~/Library/Caches \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || log "Warning: cache cleanup timed out or failed"
    else
      # Fallback without timeout - use background process with manual timeout
      find ~/Library/Caches \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null &
      local find_pid=$!
      local elapsed=0
      while kill -0 $find_pid 2>/dev/null && [ $elapsed -lt 300 ]; do
        sleep 5
        elapsed=$((elapsed + 5))
        if [ $((elapsed % 30)) -eq 0 ]; then
          log "Still cleaning caches... (${elapsed}s elapsed)"
        fi
      done
      if kill -0 $find_pid 2>/dev/null; then
        log "Warning: cache cleanup taking too long, killing process"
        kill $find_pid 2>/dev/null || true
      fi
      wait $find_pid 2>/dev/null || log "Warning: cache cleanup completed with warnings"
    fi
    log "Cache cleanup completed"
  fi
}

mac_system_maintenance() {
  log "Running system maintenance scripts..."
  
  # Run periodic maintenance scripts (macOS specific)
  if command -v periodic >/dev/null 2>&1; then
    sudo periodic daily weekly monthly || log "Warning: periodic maintenance failed"
  else
    # Alternative: run maintenance tasks manually on newer macOS
    log "Running manual maintenance tasks..."
    sudo /usr/libexec/locate.updatedb || log "Warning: locate database update failed"
  fi
  
  # Flush DNS cache
  log "Flushing DNS cache..."
  sudo dscacheutil -flushcache || log "Warning: DNS cache flush failed"
  run_with_fallback "sudo killall -HUP mDNSResponder" "mDNSResponder restart" true
}

mac_spotlight_rebuild() {
  log "Rebuilding Spotlight index..."
  sudo mdutil -E / || log "Warning: Spotlight rebuild failed"
}

mac_reset_launchpad() {
  log "Resetting Launchpad..."
  defaults write com.apple.dock ResetLaunchPad -bool true
  run_with_fallback "killall Dock" "Dock restart" true
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
  # Request administrator privileges with native dialog (includes Touch ID)
  echo "Requesting administrator privileges..."
  if ! sudo -v; then
    log "Authentication failed. Exiting."
    exit 1
  fi

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
    if [[ -z "${skip_xcode_select:-}" ]] && command_exists xcode-select; then
      log "Updating Apple Command Line Tools..."
      sudo xcodebuild -license accept 2>/dev/null || log "Warning: xcodebuild license accept failed"
      xcode-select --install 2>/dev/null || log "Command line tools already installed or installation failed"
    elif [[ -n "${skip_xcode_select:-}" ]]; then
      log "Skipped xcode-select"
    fi

    if command_exists brew; then
      update_homebrew true

      # Homebrew services cleanup
      log "Cleaning up Homebrew services..."
      brew services cleanup || log "Warning: brew services cleanup failed"
    fi

    # CocoaPods update (iOS/macOS development)
    if command_exists pod; then
      log "Updating CocoaPods repositories..."
      pod repo update || log "Warning: pod repo update failed"
    fi

    if [[ -z "${skip_softwareupdate:-}" ]] && command_exists softwareupdate; then
      log "Updating Apple Software Update"
      softwareupdate --install --all --verbose || log "Warning: softwareupdate failed"
    elif [[ -n "${skip_softwareupdate:-}" ]]; then
      log "Skipped softwareupdate"
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

    # Run macOS maintenance tasks (can be skipped with environment variables)
    if [[ -z "${skip_disk_maintenance:-}" ]]; then
      mac_disk_maintenance
    else
      log "Skipped disk_maintenance"
    fi

    if [[ -z "${skip_system_maintenance:-}" ]]; then
      mac_system_maintenance
    else
      log "Skipped system_maintenance"
    fi

    # Optional maintenance (can be skipped with environment variables)
    if [[ -z "${skip_spotlight:-}" ]]; then
      mac_spotlight_rebuild
    else
      log "Skipped spotlight"
    fi

    if [[ -z "${skip_launchpad:-}" ]]; then
      mac_reset_launchpad
    else
      log "Skipped launchpad"
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

  # Self-update (can be skipped with environment variable)
  if [[ -z "${skip_self_update:-}" ]]; then
    update_itself
  else
    log "Skipped self_update"
  fi

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

    local pip_output
    local pip_exit_code=0
    pip_output=$(pip install --upgrade pip --user 2>&1) || pip_exit_code=$?

    if [[ $pip_exit_code -ne 0 ]]; then
      # Check for externally-managed environment
      if echo "$pip_output" | grep -q "externally-managed-environment"; then
        log "Warning: pip self-update failed (externally-managed by system/Homebrew)"
      else
        log "Warning: pip self-update failed"
      fi
    fi

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

    local pip3_output
    local pip3_exit_code=0
    pip3_output=$(python3 -m pip install --upgrade pip --user 2>&1) || pip3_exit_code=$?

    if [[ $pip3_exit_code -ne 0 ]]; then
      # Check for externally-managed environment
      if echo "$pip3_output" | grep -q "externally-managed-environment"; then
        log "Warning: pip3 self-update failed (externally-managed by system/Homebrew)"
      else
        log "Warning: pip3 self-update failed"
      fi
    fi

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

  # Rust/Cargo updates
  if command_exists rustup; then
    log "Updating Rust toolchain..."
    rustup update || log "Warning: rustup update failed"
  fi

  if command_exists cargo; then
    # Check if cargo-update is installed for updating cargo packages
    if cargo install --list | grep -q "cargo-update"; then
      log "Updating cargo-installed packages..."
      cargo install-update -a || log "Warning: cargo install-update failed"
    fi
  fi

  # pnpm updates
  if command_exists pnpm; then
    log "Updating pnpm global packages..."
    pnpm update -g || log "Warning: pnpm global update failed"
  fi

  # Deno updates
  if command_exists deno; then
    log "Updating Deno..."
    deno upgrade || log "Warning: deno upgrade failed"
  fi

  # Composer (PHP) updates
  if command_exists composer; then
    log "Updating Composer global packages..."
    composer global update || log "Warning: composer global update failed"
    composer clear-cache || log "Warning: composer cache clear failed"
  fi

  # Container cleanup (Docker Desktop, OrbStack, Podman)
  if command_exists docker; then
    # Check if Docker daemon is actually running
    if ! docker info &>/dev/null; then
      log "Docker command found but daemon is not running (skipping cleanup)"
    else
      # Detect which container runtime is being used
      if pgrep -q "OrbStack"; then
        log "Cleaning up OrbStack containers..."
      elif command_exists podman && docker --version 2>/dev/null | grep -q "podman"; then
        log "Cleaning up Podman containers..."
      else
        log "Cleaning up Docker containers..."
      fi
      docker system prune -af --volumes || log "Warning: docker system prune failed"
    fi
  elif command_exists podman; then
    # Podman without docker alias - check if running
    if ! podman info &>/dev/null; then
      log "Podman command found but service is not running (skipping cleanup)"
    else
      log "Cleaning up Podman containers..."
      podman system prune -af --volumes || log "Warning: podman system prune failed"
    fi
  fi

  # asdf version manager
  if command_exists asdf; then
    log "Updating asdf..."
    asdf update || log "Warning: asdf update failed"
    asdf plugin update --all || log "Warning: asdf plugin update failed"
  fi

  # pyenv version manager
  if command_exists pyenv; then
    log "Updating pyenv..."
    if [[ -d "$(pyenv root)/.git" ]]; then
      cd "$(pyenv root)" && git pull && cd - >/dev/null || log "Warning: pyenv update failed"
    fi
  fi

  # rbenv version manager
  if command_exists rbenv; then
    log "Updating rbenv..."
    if [[ -d "$(rbenv root)/.git" ]]; then
      cd "$(rbenv root)" && git pull && cd - >/dev/null || log "Warning: rbenv update failed"
    fi
    # Update ruby-build plugin if it exists
    if [[ -d "$(rbenv root)/plugins/ruby-build/.git" ]]; then
      cd "$(rbenv root)/plugins/ruby-build" && git pull && cd - >/dev/null || log "Warning: ruby-build update failed"
    fi
  fi

  # SDKMAN version manager
  if command_exists sdk; then
    log "Updating SDKMAN..."
    sdk selfupdate || log "Warning: sdk selfupdate failed"
    sdk update || log "Warning: sdk update failed"
  fi

  # tfenv (Terraform version manager)
  if command_exists tfenv; then
    log "Updating tfenv..."
    if [[ -d "$HOME/.tfenv/.git" ]]; then
      cd "$HOME/.tfenv" && git pull && cd - >/dev/null || log "Warning: tfenv update failed"
    fi
  fi

  # Flutter
  if command_exists flutter; then
    log "Updating Flutter..."
    flutter upgrade || log "Warning: flutter upgrade failed"
  fi

  # Conda/Mamba
  if command_exists conda; then
    log "Updating Conda packages..."
    conda update --all -y || log "Warning: conda update failed"
  fi

  if command_exists mamba; then
    log "Updating Mamba packages..."
    mamba update --all -y || log "Warning: mamba update failed"
  fi

  # Helm
  if command_exists helm; then
    log "Updating Helm repositories..."
    helm repo update || log "Warning: helm repo update failed"
  fi

  # tmux plugin manager
  if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
    log "Updating tmux plugins..."
    "$HOME/.tmux/plugins/tpm/bin/update_plugins" all || log "Warning: tmux plugin update failed"
  fi

  # CPAN (Perl) - skipped by default due to macOS hardened runtime issues
  # To enable: unset skip_cpan before running or remove skip_cpan=1
  if [[ -z "${skip_cpan:-1}" ]] && command_exists cpan; then
    log "Updating CPAN modules..."
    cpan -u || log "Warning: cpan update failed"
  fi

  # Go/Golang updates
  if command_exists go; then
    log "Updating Go toolchain..."
    go install golang.org/dl/go@latest || log "Warning: go toolchain update failed"

    # Update globally installed go packages (if any)
    if [[ -d "$HOME/go/bin" ]]; then
      log "Go packages found in ~/go/bin"
      # Note: Go doesn't have a built-in update all command
      # Users typically manage this per-package
    fi
  fi

  # Poetry (Python dependency manager)
  if command_exists poetry; then
    log "Updating Poetry..."
    poetry self-update || log "Warning: poetry self-update failed"
  fi

  # PDM (Python dependency manager)
  if command_exists pdm; then
    log "Updating PDM..."
    pdm self update || log "Warning: pdm self update failed"
  fi

  # uv (Fast Python package installer and uvx tool runner)
  if command_exists uv; then
    # Check if uv was installed via Homebrew (which will update it automatically)
    uv_path=$(which uv)
    if [[ "$uv_path" =~ (/opt/homebrew|/usr/local|/home/linuxbrew) ]]; then
      log "Skipping uv self-update (managed by Homebrew)"
    else
      log "Updating uv (includes uvx)..."
      uv self update || log "Warning: uv self update failed"
    fi
  fi

  # pixi (Fast multi-language package manager built on conda ecosystem)
  if command_exists pixi; then
    log "Updating pixi..."
    pixi self-update || log "Warning: pixi self-update failed"
  fi

  # GitHub CLI
  if command_exists gh; then
    log "Updating GitHub CLI..."
    gh extension upgrade --all || log "Warning: gh extension upgrade failed"
  fi

  # Google Cloud SDK
  if command_exists gcloud; then
    log "Updating Google Cloud SDK..."
    gcloud components update --quiet || log "Warning: gcloud components update failed"
  fi

  # AWS CLI (v2 doesn't have auto-update via CLI, managed by package managers)
  if command_exists aws; then
    log "AWS CLI detected (update via package manager)"
  fi

  # Azure CLI
  if command_exists az; then
    log "Updating Azure CLI..."
    az upgrade --yes || log "Warning: az upgrade failed"
  fi

  # kubectl (Kubernetes CLI)
  if command_exists kubectl; then
    log "kubectl detected (update via package manager)"
    # kubectl doesn't have self-update, managed via package managers
  fi

  # MacPorts (alternative to Homebrew on macOS)
  if command_exists port; then
    log "Updating MacPorts..."
    sudo port selfupdate || log "Warning: port selfupdate failed"
    sudo port upgrade outdated || log "Warning: port upgrade failed"
  fi

  # Nix package manager
  if command_exists nix-env; then
    log "Updating Nix packages..."
    nix-channel --update || log "Warning: nix-channel update failed"
    nix-env -u || log "Warning: nix-env upgrade failed"
  fi

  # mise (formerly rtx) - polyglot version manager
  if command_exists mise; then
    log "Updating mise..."
    mise self-update || log "Warning: mise self-update failed"
    mise plugins update || log "Warning: mise plugins update failed"
  fi

  # proto - multi-language version manager (Rust-based alternative to asdf/mise)
  if command_exists proto; then
    log "Updating proto..."
    proto upgrade || log "Warning: proto upgrade failed"
    proto plugin upgrade || log "Warning: proto plugin upgrade failed"
  fi

  # pkgx - run anything, anywhere package runner
  if command_exists pkgx; then
    log "Updating pkgx..."
    pkgx --sync || log "Warning: pkgx sync failed"
  fi

  # Zinit (Zsh plugin manager)
  if [[ -d "$HOME/.local/share/zinit/zinit.git" ]]; then
    log "Updating Zinit..."
    zinit self-update || log "Warning: zinit self-update failed"
    zinit update --all || log "Warning: zinit update failed"
  fi

  # Antibody (Zsh plugin manager)
  if command_exists antibody; then
    log "Updating Antibody..."
    antibody update || log "Warning: antibody update failed"
  fi

  # Antigen (Zsh plugin manager)
  if [[ -f "$HOME/.antigen/antigen.zsh" ]]; then
    log "Updating Antigen plugins..."
    # Antigen updates itself and plugins on next shell load
    antigen update || log "Warning: antigen update failed"
  fi

  # Fisher (Fish shell plugin manager)
  if command_exists fisher; then
    log "Updating Fisher plugins..."
    fisher update || log "Warning: fisher update failed"
  fi

  # Starship prompt
  if command_exists starship; then
    log "Starship detected (update via package manager)"
    # Starship is typically updated via package managers
  fi

  # jenv (Java version manager)
  if command_exists jenv; then
    log "Updating jenv..."
    if [[ -d "$HOME/.jenv/.git" ]]; then
      cd "$HOME/.jenv" && git pull && cd - >/dev/null || log "Warning: jenv update failed"
    fi
  fi

  # goenv (Go version manager)
  if command_exists goenv; then
    log "Updating goenv..."
    if [[ -d "$(goenv root)/.git" ]]; then
      cd "$(goenv root)" && git pull && cd - >/dev/null || log "Warning: goenv update failed"
    fi
  fi

  # nodenv (Node version manager)
  if command_exists nodenv; then
    log "Updating nodenv..."
    if [[ -d "$(nodenv root)/.git" ]]; then
      cd "$(nodenv root)" && git pull && cd - >/dev/null || log "Warning: nodenv update failed"
    fi
    # Update node-build plugin if it exists
    if [[ -d "$(nodenv root)/plugins/node-build/.git" ]]; then
      cd "$(nodenv root)/plugins/node-build" && git pull && cd - >/dev/null || log "Warning: node-build update failed"
    fi
  fi

  if command_exists rvm; then
    log "Updating rvm"
    rvm get stable || log "Warning: rvm update failed"
    rvm cleanup all || log "Warning: rvm cleanup failed"
  fi

  sudo echo "Kept sudo."

  if command_exists gem; then
    log "Updating ruby gems..."

    local gem_output
    local gem_exit_code=0
    gem_output=$(sudo gem update 2>&1) || gem_exit_code=$?

    if [[ $gem_exit_code -ne 0 ]]; then
      # Extract failed gem names and reasons
      local failed_gems=$(echo "$gem_output" | grep -oE "Error installing [^:]+:" | sed 's/Error installing //' | sed 's/://' | tr '\n' ', ' | sed 's/,$//')
      local ruby_version_issue=$(echo "$gem_output" | grep -q "requires Ruby version" && echo " (Ruby version incompatibility)")

      if [[ -n "$failed_gems" ]]; then
        log "Warning: gem update failed for: $failed_gems$ruby_version_issue"
      else
        log "Warning: gem update failed$ruby_version_issue"
      fi
    fi

    sudo gem cleanup || log "Warning: gem cleanup failed"
  fi

  if [[ -d tmp ]]; then
    rm -rf tmp
  fi

  log "htotheizzo is complete, you got 99 problems but updates ain't one"

  # Show error summary
  show_error_summary
}

main() {
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mock)
        export MOCK_MODE=1
        log "Running in MOCK mode - commands will be logged but not executed"
        shift
        ;;
      --help|-h)
        help
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        help
        exit 1
        ;;
    esac
  done

  update
}

main "$@"
