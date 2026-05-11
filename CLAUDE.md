# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Guidelines

- **NEVER run `git commit` or `git push` unless explicitly asked by the user.**
  - Make edits freely, but wait for an explicit commit/push request before running git write commands.
  - `git status`, `git diff`, `git log`, and `git fetch/pull` are always fine.

## Overview

htotheizzo is a comprehensive system update automation script that updates multiple package managers and development tools across macOS, Linux, and Windows systems. It handles 60+ package managers and tools including:
- System packages: Homebrew, apt-get, Snap, Flatpak, Mac App Store
- Language ecosystems: npm/yarn/pnpm/Bun/Deno, pip/pipenv/conda/pixi, gem, Rust/Cargo, Composer, CPAN
- Version managers: asdf, mise, proto, nvm, pyenv, rbenv, rvm, SDKMAN, tfenv
- Infrastructure tools: Docker, OrbStack, Podman, Helm, Flutter
- Development tools: VS Code, CocoaPods, tmux plugins
- System maintenance: Cache cleanup, log rotation, disk verification (macOS)
- Package runners: pkgx

## Architecture

The codebase consists of shell scripts and a modern GUI:
- `htotheizzo.sh` - Main update script with OS detection and comprehensive package manager updates
- `htotheizzo-gui.sh` - Electron GUI launcher script
- `gui/` - Electron-based GUI application with modern interface
- `update.sh` - Windows-specific update script using Chocolatey, Winget, Scoop, and Windows Update
- `repair.sh` - macOS disk repair utility

## Key Functions

- `update_linux()` - Handles apt, snap, flatpak, and other Linux package managers
- `update_homebrew()` / `update_homebrew_with_casks()` - Homebrew updates with optional cask support
- `command_exists()` - Checks if commands exist and handles skipping via environment variables
- `update_itself()` - Self-updating mechanism using git

## Skip Commands

The script supports skipping specific package managers using environment variables:
- `skip_brew=1` - Skip Homebrew updates
- `skip_mas=1` - Skip Mac App Store updates
- `skip_snap=1` - Skip Snap package updates
- `skip_flatpak=1` - Skip Flatpak updates
- `skip_docker=1` - Skip Docker cleanup
- `skip_pod=1` - Skip CocoaPods updates
- `skip_asdf=1` - Skip asdf version manager updates
- `skip_pyenv=1` - Skip pyenv updates
- `skip_rbenv=1` - Skip rbenv updates
- `skip_sdk=1` - Skip SDKMAN updates
- `skip_tfenv=1` - Skip tfenv (Terraform) updates
- `skip_flutter=1` - Skip Flutter updates
- `skip_conda=1` - Skip Conda updates
- `skip_helm=1` - Skip Helm repository updates
- `skip_cpan=1` - Skip CPAN (Perl) updates
- `skip_go=1` - Skip Go/Golang updates
- `skip_poetry=1` - Skip Poetry updates
- `skip_pdm=1` - Skip PDM updates
- `skip_uv=1` - Skip uv/uvx updates
- `skip_pixi=1` - Skip pixi updates
- `skip_gh=1` - Skip GitHub CLI extension updates
- `skip_gcloud=1` - Skip Google Cloud SDK updates
- `skip_az=1` - Skip Azure CLI updates
- `skip_kubectl=1` - Skip kubectl detection
- `skip_port=1` - Skip MacPorts updates
- `skip_nix-env=1` - Skip Nix package manager updates
- `skip_mise=1` - Skip mise version manager updates
- `skip_proto=1` - Skip proto version manager updates
- `skip_pkgx=1` - Skip pkgx updates
- `skip_podman=1` - Skip Podman cleanup
- `skip_choco=1` - Skip Chocolatey updates (Windows)
- `skip_winget=1` - Skip Winget updates (Windows)
- `skip_scoop=1` - Skip Scoop updates (Windows)
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

### Self-Update Mechanism
The script can update itself by following symlinks to find its real location and performing a git pull in that directory.