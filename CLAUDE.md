# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

htotheizzo is a comprehensive system update automation script that updates multiple package managers and development tools across macOS, Linux, and Windows systems. It handles 50+ package managers and tools including:

- **System packages**: Homebrew, apt-get, Snap, Flatpak, Mac App Store
- **Language ecosystems**: npm/yarn/pnpm/Bun/Deno, pip/pipenv/conda, gem, Rust/Cargo, Composer, CPAN
- **Version managers**: asdf, nvm, pyenv, rbenv, rvm, SDKMAN, tfenv
- **Infrastructure tools**: Docker, Helm, Flutter
- **Development tools**: VS Code, CocoaPods, tmux plugins
- **System maintenance**: Cache cleanup, log rotation, disk verification (macOS)

All in a single command with intelligent error handling and skip options.

## Architecture

The codebase consists of shell scripts and a modern GUI:

- `htotheizzo.sh` - Main update script with OS detection and comprehensive package manager updates
- `htotheizzo-gui.sh` - Electron GUI launcher script
- `gui/` - Electron-based GUI application with modern interface
- `update.sh` - Windows-specific update script using Chocolatey and Windows Update
- `repair.sh` - macOS disk repair utility

### Main Script Structure (`htotheizzo.sh`)

The script follows a modular approach with these key components:

1. **Native Authentication**: Uses `sudo -v` for native macOS authentication with Touch ID support
2. **OS Detection**: Detects Linux, macOS, or Raspberry Pi environments
3. **Command Skipping**: Environment variable-based command skipping (e.g., `skip_brew=1`)
4. **Package Manager Updates**: Separate functions for each package manager
5. **Self-Update**: Built-in git pull functionality to update the script itself

### Key Functions

- `update_linux()` - Handles apt, snap, flatpak, and other Linux package managers
- `update_homebrew()` / `update_homebrew_with_casks()` - Homebrew updates with optional cask support
- `command_exists()` - Checks if commands exist and handles skipping via environment variables
- `update_itself()` - Self-updating mechanism using git

## Setup

First time setup requires cloning and linking:

```bash
mkdir -p ~/bin
git clone https://github.com/yanicklandry/htotheizzo.git ~/bin/.htotheizzo
ln -s ~/bin/.htotheizzo/htotheizzo.sh ~/bin/htotheizzo.sh
chmod a+x ~/bin/htotheizzo.sh
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Linux-Specific Setup

For Homebrew on Linux as root:

```bash
sudo echo "sudo -u $(whoami) $(which brew) \$@" > /usr/local/bin/brew
sudo chmod a+x /usr/local/bin/brew
```

## Common Commands

### Running the Update Script

```bash
# Basic usage (recommended to have sudo authorization first)
sudo ls  # enter password to cache sudo
./htotheizzo.sh

# Skip specific package managers
skip_brew=1 skip_mas=1 ./htotheizzo.sh

# On Linux (may require sudo for some operations)
sudo ./htotheizzo.sh
```

### Automated Scheduling with Cron

For automatic updates, you can schedule htotheizzo using cron. Here are recommended schedules:

#### Weekly Updates (Recommended)
```bash
# Edit crontab
crontab -e

# Add this line for weekly updates on Sundays at 2 AM
0 2 * * 0 /Users/$(whoami)/bin/htotheizzo.sh >> /Users/$(whoami)/logs/htotheizzo.log 2>&1
```

#### Other Scheduling Options
```bash
# Daily updates at 3 AM (for development machines)
0 3 * * * /Users/$(whoami)/bin/htotheizzo.sh >> /Users/$(whoami)/logs/htotheizzo.log 2>&1

# Bi-weekly updates (1st and 15th of each month at 2 AM)
0 2 1,15 * * /Users/$(whoami)/bin/htotheizzo.sh >> /Users/$(whoami)/logs/htotheizzo.log 2>&1

# Weekday updates at 1 AM (Monday-Friday)
0 1 * * 1-5 /Users/$(whoami)/bin/htotheizzo.sh >> /Users/$(whoami)/logs/htotheizzo.log 2>&1
```

#### Setup Steps for Automated Updates

1. **Create log directory:**
   ```bash
   mkdir -p ~/logs
   ```

2. **Test the script path:**
   ```bash
   which htotheizzo.sh
   # Use the full path in your crontab
   ```

3. **Add to crontab:**
   ```bash
   crontab -e
   # Add your chosen schedule from above
   ```

4. **Verify cron job:**
   ```bash
   crontab -l
   ```

#### Important Cron Considerations

- **Sudo access**: For automated runs, consider configuring passwordless sudo for specific commands or run as root (not recommended)
- **Environment variables**: Cron has a minimal environment, so use full paths
- **Logging**: Always redirect output to a log file to troubleshoot issues
- **Network connectivity**: Ensure the system has internet access during scheduled runs
- **System load**: Schedule during low-usage periods (typically early morning)

### Windows Updates

```bash
# Windows-specific updates (Chocolatey and Windows Update)
./update.sh
```

### macOS Disk Repair

```bash
# Simple disk repair utility
./repair.sh
```

## Skip Commands

The script supports skipping specific package managers using environment variables:

- `skip_brew=1` - Skip Homebrew updates
- `skip_mas=1` - Skip Mac App Store updates
- `skip_kav=1` - Skip Kaspersky updates
- `skip_snap=1` - Skip Snap package updates
- `skip_flatpak=1` - Skip Flatpak updates
- `skip_bun=1` - Skip Bun updates
- `skip_spotlight=1` - Skip Spotlight index rebuild (macOS only)
- `skip_launchpad=1` - Skip Launchpad reset (macOS only)
- `skip_rustup=1` - Skip Rust toolchain updates
- `skip_cargo=1` - Skip Cargo package updates
- `skip_pnpm=1` - Skip pnpm updates
- `skip_deno=1` - Skip Deno updates
- `skip_composer=1` - Skip Composer (PHP) updates
- `skip_docker=1` - Skip Docker cleanup
- `skip_pod=1` - Skip CocoaPods updates
- `skip_asdf=1` - Skip asdf version manager updates
- `skip_pyenv=1` - Skip pyenv updates
- `skip_rbenv=1` - Skip rbenv updates
- `skip_sdk=1` - Skip SDKMAN updates
- `skip_tfenv=1` - Skip tfenv (Terraform) updates
- `skip_flutter=1` - Skip Flutter updates
- `skip_conda=1` - Skip Conda updates
- `skip_mamba=1` - Skip Mamba updates
- `skip_helm=1` - Skip Helm repository updates
- `skip_cpan=1` - Skip CPAN (Perl) updates
- `skip_go=1` - Skip Go/Golang updates
- `skip_poetry=1` - Skip Poetry updates
- `skip_pdm=1` - Skip PDM updates
- `skip_uv=1` - Skip uv updates
- `skip_gh=1` - Skip GitHub CLI extension updates
- `skip_gcloud=1` - Skip Google Cloud SDK updates
- `skip_aws=1` - Skip AWS CLI detection
- `skip_az=1` - Skip Azure CLI updates
- `skip_kubectl=1` - Skip kubectl detection
- `skip_port=1` - Skip MacPorts updates
- `skip_nix-env=1` - Skip Nix package manager updates
- `skip_mise=1` - Skip mise version manager updates
- `skip_antibody=1` - Skip Antibody updates
- `skip_fisher=1` - Skip Fisher updates
- `skip_starship=1` - Skip Starship detection
- `skip_jenv=1` - Skip jenv updates
- `skip_goenv=1` - Skip goenv updates
- `skip_nodenv=1` - Skip nodenv updates

## Platform-Specific Behavior

### macOS
- Updates Homebrew (including casks with `--greedy` flag)
- Homebrew services cleanup
- Updates CocoaPods repositories (iOS/macOS development)
- Updates Mac App Store apps via `mas`
- Installs/updates Apple Command Line Tools
- Runs macOS Software Update
- Updates Microsoft Office via AutoUpdate
- **Maintenance Tasks:**
  - Verifies disk integrity using `diskutil`
  - Clears memory and user caches
  - Runs system periodic maintenance scripts
  - Flushes DNS cache
  - Rebuilds Spotlight index (optional, can skip with `skip_spotlight=1`)
  - Resets Launchpad layout (optional, can skip with `skip_launchpad=1`)

### Linux
- Updates apt packages with full cleanup
- Updates Snap packages and removes old revisions
- Updates Flatpak packages
- Cleans system logs using journalctl
- Supports Homebrew on Linux

### Cross-Platform

**JavaScript/Node.js:**
- npm (with global package updates and cache cleanup)
- yarn (supports Homebrew, corepack, and npm installation methods)
- pnpm (global package updates)
- nvm (Node version manager)
- Bun (JavaScript runtime and package manager)
- Deno (modern JavaScript/TypeScript runtime)

**Python:**
- pip/pip3 (user packages with safety flags)
- pipenv (cache clearing)
- pyenv (Python version manager)
- Conda/Mamba (Python environment managers)
- Poetry (modern dependency manager with self-update)
- PDM (modern dependency manager with self-update)
- uv (fast package installer with self-update)

**Ruby:**
- gem (system gems with cleanup)
- rvm (Ruby version manager with cleanup)
- rbenv (Ruby version manager with ruby-build plugin)

**Rust:**
- rustup (Rust toolchain updates)
- cargo (cargo-installed package updates via cargo-update)

**PHP:**
- Composer (global packages and cache clearing)

**Go:**
- Go toolchain updates
- Globally installed Go packages (via go install)

**Java/JVM:**
- SDKMAN (Java/JVM version manager)
- jenv (Java version manager)

**Infrastructure/DevOps:**
- Docker (system prune for unused images/containers/volumes)
- Helm (Kubernetes package manager repository updates)
- kubectl (Kubernetes CLI - detected, updated via package managers)
- Terraform (tfenv version manager)

**Cloud Provider CLIs:**
- GitHub CLI (gh) - extension updates
- Google Cloud SDK (gcloud) - component updates
- AWS CLI - detected, updated via package managers
- Azure CLI (az) - self-update

**Multi-Language Version Managers:**
- asdf (universal version manager with plugin updates)
- mise (formerly rtx - modern polyglot version manager)

**Language-Specific Version Managers:**
- nvm (Node version manager)
- nodenv (Node version manager - alternative to nvm)
- pyenv (Python version manager)
- rbenv (Ruby version manager with ruby-build plugin)
- rvm (Ruby version manager with cleanup)
- goenv (Go version manager)
- jenv (Java version manager)
- tfenv (Terraform version manager)
- SDKMAN (Java/JVM/Gradle/Maven version manager)

**Package Manager Alternatives:**
- MacPorts (macOS package manager - alternative to Homebrew)
- Nix (cross-platform functional package manager)

**Shell Customization:**
- Oh My ZSH (Zsh framework with omz command)
- Zinit (Zsh plugin manager with self-update)
- Antibody (Zsh plugin manager)
- Antigen (Zsh plugin manager)
- Fisher (Fish shell plugin manager)
- Starship (cross-shell prompt - detected)

**Development Tools:**
- VS Code extensions
- Flutter (mobile development framework)
- tmux plugin manager (if tpm is installed)
- CocoaPods (iOS/macOS dependency manager)

**Other:**
- Atom packages (via apm, if installed)
- CPAN (Perl modules)
- Kaspersky Security Tools (if installed)
- Self-updates the script via git

## Error Handling

The script includes comprehensive error handling:

- All commands use `|| log "Warning: ..."` for graceful failure handling
- Sudo access is tested before critical operations
- Package manager existence is checked via `command_exists()` function  
- Failed operations log warnings but don't stop the entire update process
- Uses `set -euo pipefail` for strict error handling in main script

## Technical Details

### Docker Integration
- Replaces systemd files from `~/.sysd/` if directory exists
- Restarts Docker service after systemd updates
- Performs system-wide cleanup to remove:
  - Unused images
  - Stopped containers
  - Unused volumes
  - Unused networks
  - Build cache

### Security Considerations
- Uses `export DEBIAN_FRONTEND=noninteractive` for non-interactive apt operations
- Temporarily disables `PIP_REQUIRE_VIRTUALENV` during pip updates
- Cleans package caches and removes unused packages
- Safer snap removal by parsing disabled snaps first

### Self-Update Mechanism
The script can update itself by following symlinks to find its real location and performing a git pull in that directory.

## GUI Application

The project includes a modern Electron-based GUI that provides an intuitive interface for running system updates.

### GUI Features
- **Native Authentication**: Integrates with macOS native authentication dialogs including Touch ID
- **Package Selection**: Checkboxes for each package manager (Homebrew, Mac App Store, Snap, etc.)
- **Real-time Output**: Live display of update progress and logs
- **Error Handling**: Clear error messages and status indicators
- **Modern Interface**: Clean, native-looking macOS design

### GUI Architecture
- `gui/main.js` - Electron main process handling authentication and script execution
- `gui/renderer.js` - Frontend logic for UI interactions and real-time updates
- `gui/index.html` - Modern HTML interface with responsive design
- `gui/package.json` - Node.js dependencies and Electron configuration

### Running the GUI

```bash
# Launch GUI via terminal command
htotheizzo-gui

# Or run directly
/Users/$(whoami)/bin/.htotheizzo/htotheizzo-gui.sh

# Or from the gui directory
cd ~/bin/.htotheizzo/gui && npm start
```

### GUI Setup

The GUI requires Node.js and is automatically set up when first launched:

```bash
# The GUI launcher automatically:
# 1. Checks for Node.js and npm
# 2. Installs dependencies if needed
# 3. Launches the Electron application
```

### GUI Authentication

The GUI uses the same native authentication as the command-line script:
- Prompts for administrator privileges using macOS native dialog
- Supports Touch ID authentication when available
- Handles authentication failures gracefully with clear error messages

### Package Manager Selection

The GUI provides intuitive checkboxes for all supported package managers:
- All options are **enabled by default** 
- **Uncheck** items you want to **skip**
- Supports all skip variables: `skip_brew`, `skip_mas`, `skip_spotlight`, etc.