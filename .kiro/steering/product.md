# Product Overview

htotheizzo is a single-command system updater for developers. It runs all your package managers and development tools in one pass — Homebrew, mas, npm, pip, gem, Rust, and 50+ more — so you never have to remember which updater to run.

## Core Capabilities

- **Universal update pass**: One command updates all installed package managers, version managers, cloud CLIs, and development tools across macOS, Linux, and Windows.
- **Selective execution system**: Two complementary env var modes: `skip_<name>=1` to exclude categories, `only_<name>=1` to run only specific categories. No config files or flags.
- **Safe failure handling**: A failed updater logs a warning and continues; the summary at the end shows what went wrong without stopping the run.
- **Electron GUI**: A native macOS GUI with Touch ID auth, per-category checkboxes, and real-time progress output.
- **Self-update**: The script finds its own git clone via symlink resolution and pulls on each run.
- **Sparkle app updates**: macOS-only section auto-discovers installed apps with a Sparkle `SUFeedURL` (default `/Applications`, override via `SPARKLE_APP_DIRS`) and delegates each to antares `bin/updates-apply.sh` (default `~/Developer/2026/antares`, override via `ANTARES_DIR`). Gated on `skip_sparkle=1`/`only_sparkle=1` via `should_run`; silently skips if the antares updater binary isn't executable. Running apps can be skipped with `skip_sparkle_running=1`.
- **Touch ID-friendly sudo**: keepalive interval tuned to avoid re-prompting within the 5-minute macOS sudo timeout; major OS upgrade detection warns before `softwareupdate --install --all`.
- **Preflight system checks**: Before updating, warns (non-blocking) on low disk space, no network, long uptime, and low battery. Each check is individually skippable (`skip_disk_check=1`, etc.).
- **File logging with rotation, desktop notifications, and cron install helper**: Persistent log file at `~/logs/htotheizzo.log` with rotation, native macOS/Linux desktop notifications on completion, and a guided `install_cron_job` flow that prints a ready-to-use weekly crontab entry.
- **Pre-update safety net**: Optional APFS/Time Machine local snapshot (macOS) or guidance for BTRFS/LVM/Timeshift (Linux) before the run, plus a security-update info panel pointing to OS-specific mechanisms (RSR, unattended-upgrades).
- **Browser cache cleanup and AppImage awareness**: Cleans browser caches on request; on Linux, detects installed AppImages and surfaces available update tooling (informational, since AppImage has no universal updater).

## Target Use Cases

- Developer who wants "update everything" without memorizing per-tool commands
- CI or cron automation for periodic system hygiene (weekly recommended)
- New machine setup and onboarding

## Value Proposition

htotheizzo removes the cognitive overhead of maintaining a development machine. Its skip system and graceful error handling make it safe to run in automated contexts where not every tool is installed.

---
_Focus on patterns and purpose, not exhaustive feature lists_
