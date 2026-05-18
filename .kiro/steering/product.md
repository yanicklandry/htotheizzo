# Product Overview

htotheizzo is a single-command system updater for developers. It runs all your package managers and development tools in one pass — Homebrew, mas, npm, pip, gem, Rust, and 50+ more — so you never have to remember which updater to run.

## Core Capabilities

- **Universal update pass**: One command updates all installed package managers, version managers, cloud CLIs, and development tools across macOS, Linux, and Windows.
- **Selective skip system**: Any category can be skipped via `skip_<name>=1` environment variables — no config files, no flags, just env vars.
- **Safe failure handling**: A failed updater logs a warning and continues; the summary at the end shows what went wrong without stopping the run.
- **Electron GUI**: A native macOS GUI with Touch ID auth, per-category checkboxes, and real-time progress output.
- **Self-update**: The script finds its own git clone via symlink resolution and pulls on each run.

## Target Use Cases

- Developer who wants "update everything" without memorizing per-tool commands
- CI or cron automation for periodic system hygiene (weekly recommended)
- New machine setup and onboarding

## Value Proposition

htotheizzo removes the cognitive overhead of maintaining a development machine. Its skip system and graceful error handling make it safe to run in automated contexts where not every tool is installed.

---
_Focus on patterns and purpose, not exhaustive feature lists_
