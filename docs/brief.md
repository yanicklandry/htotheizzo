# Brief: htotheizzo

## Problem
Maintaining a development machine means remembering and running a dozen or more update commands: Homebrew, mas, npm, pip, gem, Rust, cloud CLIs, version managers, and more. Each has its own syntax, and not every tool is installed on every machine. The cognitive overhead is real, so updates get skipped and machines drift out of date.

## What It Is
htotheizzo is a single-command system updater. One run updates every installed package manager, version manager, cloud CLI, and development tool in a single pass across macOS, Linux, and Windows. It is a personal utility script that lives in these dotfiles and is exposed on `$PATH`.

## Core Capabilities
- **Universal update pass**: Updates 50+ package managers and tools in one command (Homebrew, mas, npm, pip, gem, Rust, and more).
- **Selective skip system**: Any category is skipped with a `skip_<name>=1` environment variable. No config files, no flags.
- **Safe failure handling**: A failed updater logs a warning and continues; an end-of-run summary reports what went wrong without aborting the pass.
- **Cache cleanup**: After each tool updates, its documented cache-purge command runs (npm, Homebrew, Composer, Pipenv, pip, uv, docker builder, yarn, cargo), gated on tool presence.
- **Electron GUI**: Native macOS GUI with Touch ID auth, per-category checkboxes, and real-time progress output.
- **Self-update**: The script resolves its own git clone via symlink and pulls on each run.

## Architecture
- `htotheizzo.sh` — main update script; handles all package managers, the skip system, sudo auth, and the summary.
- `htotheizzo-gui.sh` — shell launcher for the Electron GUI.
- `gui/main.js` — Electron main process (IPC, script execution).
- `gui/renderer.js` — frontend logic (checkboxes, progress, output).
- `gui/index.html` — UI layout and CSS.
- `htotheizzo.app/` — macOS `.app` bundle for Finder/Dock launching; must stay inside the repo since the launcher resolves its path relative to the bundle.

The project follows a Kiro-style spec-driven workflow: steering docs in `.kiro/steering/`, feature specs in `.kiro/specs/`.

## Target Use Cases
- A developer who wants "update everything" without memorizing per-tool commands.
- CI or cron automation for periodic system hygiene (weekly recommended).
- New machine setup and onboarding.

## Value Proposition
htotheizzo removes the cognitive overhead of maintaining a development machine. Its skip system and graceful error handling make it safe to run in automated contexts where not every tool is installed.

## Current State
Recent work (per roadmap and specs) has focused on:
- **script-cleanup** (done): removed non-best-practice features (load check, backup reminder) and dead code; fixed performance issues (duplicate `softwareupdate` call, oversized cache timeouts, redundant `sudo -v` calls).
- **cache-cleanup** (done): added the missing documented cache-purge commands (pip, uv, docker builder, yarn, cargo) following the existing `command_exists` + `|| log "Warning: ..."` pattern.
- **sparkle-app-updates**, **sudo-auth** (spec'd): additional feature specs in `.kiro/specs/`.

See `PLAN.md` for the consolidated bug and enhancement backlog, and `MEMORY.md` for the GUI backlog.

## Constraints
- Must preserve `set -euo pipefail` correctness.
- Every cleanup/update command must be gated on `command_exists` and use the `|| log "Warning: ..."` fallback.
- Skip flags (`skip_<name>=1`) must keep working for all affected sections.
- No build system and no tests beyond `test.sh` — changes are applied by editing and re-running.
- `test.sh` must pass after changes.

## Out of Scope
- New package manager support beyond documented, established tools.
- Windows/Linux-specific feature parity work.
- Architectural refactors of the main script.
