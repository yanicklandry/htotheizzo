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

## Common Commands

### Running the Update Script

```bash
# Basic usage
./htotheizzo.sh

# Skip specific package managers
skip_brew=1 skip_mas=1 ./htotheizzo.sh

# On Linux (may require sudo for some operations)
sudo ./htotheizzo.sh
```

### Windows Updates

```bash
# Windows-specific updates
./update.sh
```

### macOS Disk Repair

```bash
# Run disk repair utility
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
- Updates Python pip packages
- Updates Ruby gems
- Updates VS Code extensions
- Self-updates the script via git