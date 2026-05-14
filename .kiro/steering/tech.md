# Technology Stack

## Architecture

Two independent layers that share no runtime coupling:

1. **Shell script layer** (`htotheizzo.sh`): Bash with `set -euo pipefail`. Handles all package manager logic. OS-detected branching (macOS / Linux / Windows). No external dependencies beyond standard POSIX tools.
2. **GUI layer** (`gui/`): Electron 39+ app. Spawns the shell script in a PTY via `node-pty`. Communicates over IPC. The GUI is a wrapper — it has no update logic of its own.

## Core Technologies

- **Language**: Bash (shell script), JavaScript (GUI)
- **Framework**: Electron 39+ (GUI only)
- **Runtime**: Node.js 18+ (GUI only), macOS/Linux/Windows shell (script)

## Key Technical Decisions

- **Structured progress events**: The script emits `PROGRESS:<label>` lines on stdout; the GUI parser reads these to drive the progress display. This is the approved pattern — do not use `simulateProgress()` for new work.
- **Sudo keepalive**: A background `sudo -v` loop (`keep_sudo_alive()`) runs for the duration of `update()`. Do not add additional `sudo -v` calls at the top of individual updater blocks.
- **`maybe_run()`**: Wraps commands for `MOCK_MODE` support. Use for commands that should be skippable in testing.
- **`command_exists()`**: Always gate on this before invoking a tool. Absence of a tool is silent skip, not an error.
- **`MAS_NO_AUTO_INDEX=1`**: Set before `mas upgrade` to suppress the auto-index warning.

## Development Standards

### Shell
- `set -euo pipefail` at the top — strict mode is on
- All fallible commands end with `|| log "Warning: ..."` to prevent aborting the entire run
- New package manager blocks follow the existing `if command_exists <tool>; then ... fi` pattern

### GUI
- IPC channels: `run-htotheizzo` (start), `stop-htotheizzo` (stop), `htotheizzo-output` (stream), `htotheizzo-done` (complete)
- `preload.js` exposes the IPC bridge — do not access `ipcRenderer` directly from renderer code

## Development Environment

### Required Tools
- Bash 5+ (macOS ships Bash 3 — test with `/usr/local/bin/bash` or `brew install bash`)
- Node.js 18+ and npm (for GUI development)
- Electron (installed via `npm install` in `gui/`)

### Common Commands
```bash
# Run script directly
./htotheizzo.sh

# Run in mock mode (no real changes)
MOCK_MODE=1 ./htotheizzo.sh

# Launch GUI (dev mode)
cd gui && npm start

# Run test suite
./test.sh
```

---
_Document standards and patterns, not every dependency_
