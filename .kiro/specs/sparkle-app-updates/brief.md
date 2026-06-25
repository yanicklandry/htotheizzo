# Brief: sparkle-app-updates

## Problem
htotheizzo updates 60+ package managers but has **zero handling for Sparkle apps** — third-party macOS apps that self-update via the Sparkle framework (and are not installed as Homebrew casks). These apps only update when launched and prompted interactively, so an unattended `htotheizzo` run silently leaves them stale. The user's colleague's tool, **antares** (`/Users/yanick/Developer/2026/antares`), already solves the per-app Sparkle update; htotheizzo should leverage it so a single update run also brings Sparkle apps current.

## Current State
- `htotheizzo.sh` performs updates across brew/mas/npm/etc., macOS-only sections gated by `skip_<name>=1`, with `set -euo pipefail`, `command_exists()` gating, and `|| log "Warning: ..."` fallbacks. No `sparkle`/`appcast` references exist.
- **antares** provides `bin/update-app.sh <AppName|/path/App.app> [--dry-run]`: reads the app's `SUFeedURL`, fetches the appcast, finds the newest **stable** version + `.dmg`/`.zip` enclosure, and (if behind) downloads, installs into `/Applications`, relaunches if the app was running, and clears antares' sparkle health-cache. Uses only curl + hdiutil/ditto + osascript. It is opt-in and operates on **one named app** at a time; antares' daily report never calls it.
- antares' `health-check.sh`/`outdated.sh` only *count/list* pending Sparkle updates (suggest-only).

## Desired Outcome
During a macOS `htotheizzo` run, all installed Sparkle apps that are behind their appcast's newest stable version are automatically updated by delegating to antares' `update-app.sh`, with the same logging, error-tolerance, skip-flag, and non-interactive behavior as every other htotheizzo section.

## Approach
Add a new macOS-only `update_sparkle_apps()` section that:
1. **Locates antares' `update-app.sh`**: resolve `$ANTARES_DIR` if set, else fall back to `~/Developer/2026/antares`; treat a missing/non-executable `bin/update-app.sh` like a missing command (skip with a log line, never error the run).
2. **Discovers Sparkle apps**: scan `/Applications/*.app` (and optionally `~/Applications/*.app`) reading `defaults read <App>/Contents/Info SUFeedURL`; keep only apps whose feed is an `http(s)` URL.
3. **Updates each app**: invoke `update-app.sh "<AppName>"` per discovered app. `update-app.sh` is itself a no-op when already current, so htotheizzo does not need to pre-check versions. Wrap each call in `|| log "Warning: ..."` so one failure never aborts the run.
4. **Respects conventions**: gate the whole section on `skip_sparkle=1`; run non-interactively; preserve `set -euo pipefail` correctness.

## Scope
- **In**: New `update_sparkle_apps()` function called from the macOS update path; antares-dir resolution; `/Applications` Sparkle discovery via `SUFeedURL`; per-app delegation to `update-app.sh`; `skip_sparkle=1` flag; logging + warning-tolerant error handling; doc update in `CLAUDE.md` skip-commands list.
- **Out**: Modifying antares itself; reporting-only / dry-run-only modes (user chose auto-update); Sparkle apps installed as brew casks (already covered by brew cask updates); Linux/Windows; rewriting appcast parsing in htotheizzo (delegated to antares); GUI changes.

## Boundary Candidates
- antares-location resolution (env var + fallback + graceful skip)
- Sparkle-app discovery (enumerate `/Applications`, filter by valid `SUFeedURL`)
- Per-app update invocation + error/log handling
- Skip-flag wiring + documentation

## Out of Boundary
- antares' internal appcast parsing / install logic (owned by antares `update-app.sh`)
- Brew-cask-managed apps (owned by existing homebrew cask update path)
- Deciding *whether* an app is outdated (delegated to `update-app.sh`'s own version check)

## Upstream / Downstream
- **Upstream**: antares repo (`bin/update-app.sh`) must be present and executable; macOS-only (`defaults`, `/Applications`); existing htotheizzo `log()` / `command_exists()` / skip-flag machinery.
- **Downstream**: GUI (`gui/`) may later expose a "skip Sparkle" checkbox mirroring `skip_sparkle`; not in this spec.

## Existing Spec Touchpoints
- **Extends**: none — new capability.
- **Adjacent**: `cache-cleanup` / `script-cleanup` (closed cleanup roadmap) and `sudo-auth` all touch `htotheizzo.sh`; avoid overlapping their sections. This adds a new section rather than altering theirs.

## Constraints
- Preserve `set -euo pipefail` correctness (guard empty-glob / no-Sparkle-apps cases).
- Gate on `command_exists`-style availability of `update-app.sh`; skip cleanly when antares is absent.
- Every per-app call uses `|| log "Warning: ..."` so failures don't abort the run.
- `skip_sparkle=1` must fully bypass the section.
- Fully non-interactive — `update-app.sh` may quit/relaunch a running app via `osascript`; acceptable per the auto-update decision, but the run must not block on prompts.
- macOS-only; never invoked on Linux/Windows paths.
