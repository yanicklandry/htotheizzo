#!/bin/bash
# Windows system update script for htotheizzo
# Supports Chocolatey, Winget, Scoop, and Windows Update

set -euo pipefail

# Helper function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null && [[ -z "${skip_$1:-}" ]]
}

# Helper function for logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Chocolatey
if command_exists choco; then
  log "Updating Chocolatey packages..."
  choco upgrade all -y || log "Warning: Chocolatey upgrade failed"
else
  log "Chocolatey not found (install from https://chocolatey.org)"
fi

# Winget (built into Windows 11)
if command_exists winget; then
  log "Updating Winget packages..."
  winget upgrade --all --silent --accept-package-agreements --accept-source-agreements || log "Warning: Winget upgrade failed"
else
  log "Winget not found (built into Windows 11, or install App Installer from Microsoft Store)"
fi

# Scoop
if command_exists scoop; then
  log "Updating Scoop..."
  scoop update || log "Warning: Scoop update failed"
  scoop update --all || log "Warning: Scoop package upgrade failed"
  scoop cleanup --all || log "Warning: Scoop cleanup failed"
  scoop cache rm --all || log "Warning: Scoop cache cleanup failed"
else
  log "Scoop not found (install from https://scoop.sh)"
fi

# Windows Update
log "Running Windows Update..."
if command_exists powershell; then
  # Modern approach using PowerShell (Windows 10+)
  powershell -Command "Install-Module PSWindowsUpdate -Force -SkipPublisherCheck; Import-Module PSWindowsUpdate; Get-WindowsUpdate -AcceptAll -Install -AutoReboot" || log "Warning: Windows Update via PowerShell failed"
else
  # Fallback to legacy method
  wuauclt /detectnow /updatenow || log "Warning: Windows Update failed"
fi

log "Windows system update complete!"
