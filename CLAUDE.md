# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

htotheizzo is a system update automation script that updates multiple package managers and tools across macOS, Linux, and Windows systems. It handles Homebrew, apt-get, npm, pip, gems, and various other package managers in a single command.

## Architecture

The codebase consists of three main shell scripts:

- `htotheizzo.sh` - Main update script with OS detection and comprehensive package manager updates
- `update.sh` - Windows-specific update script using Chocolatey and Windows Update
- `repair.sh` - macOS disk repair utility

### Main Script Structure (`htotheizzo.sh`)

The script follows a modular approach with these key components:

1. **OS Detection**: Detects Linux, macOS, or Raspberry Pi environments
2. **Command Skipping**: Environment variable-based command skipping (e.g., `skip_brew=1`)
3. **Package Manager Updates**: Separate functions for each package manager
4. **Self-Update**: Built-in git pull functionality to update the script itself

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

## Platform-Specific Behavior

### macOS
- Updates Homebrew (including casks with `--greedy` flag)
- Updates Mac App Store apps via `mas`
- Installs/updates Apple Command Line Tools
- Runs macOS Software Update
- Updates Microsoft Office via AutoUpdate

### Linux
- Updates apt packages with full cleanup
- Updates Snap packages and removes old revisions
- Updates Flatpak packages
- Cleans system logs using journalctl
- Supports Homebrew on Linux

### Cross-Platform
- Updates npm packages globally
- Updates Python pip packages (with user flag for safety)
- Updates Ruby gems
- Updates yarn, nvm, rvm, pipenv
- Updates VS Code extensions
- Updates Oh My ZSH and Atom packages (if installed)
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

### Security Considerations
- Uses `export DEBIAN_FRONTEND=noninteractive` for non-interactive apt operations
- Temporarily disables `PIP_REQUIRE_VIRTUALENV` during pip updates
- Cleans package caches and removes unused packages
- Safer snap removal by parsing disabled snaps first

### Self-Update Mechanism
The script can update itself by following symlinks to find its real location and performing a git pull in that directory.