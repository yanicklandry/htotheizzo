#!/bin/bash

# htotheizzo GUI launcher script
# This script launches the Electron GUI for htotheizzo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUI_DIR="$SCRIPT_DIR/gui"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Check if Node.js is installed
if ! command -v node >/dev/null 2>&1; then
    log "Error: Node.js is not installed. Please install Node.js to run the GUI."
    exit 1
fi

# Check if npm is installed
if ! command -v npm >/dev/null 2>&1; then
    log "Error: npm is not installed. Please install npm to run the GUI."
    exit 1
fi

# Navigate to GUI directory
cd "$GUI_DIR"

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    log "Installing GUI dependencies..."
    npm install
fi

# Check if Electron is installed locally
if [ ! -d "node_modules/electron" ]; then
    log "Installing Electron..."
    npm install electron --save-dev
fi

# Launch the GUI
log "Starting htotheizzo GUI..."
if [ "${1:-}" = "--dev" ]; then
    npm run dev
else
    npm start
fi