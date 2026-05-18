# Brief: script-cleanup

## Problem
htotheizzo includes features that are not established best practices and add noise/latency to every run: a system load average check (warns if load > 4.0) and a backup reminder (checks Time Machine status). Dead code (`replace_sysd()`) is also present. Additionally, `softwareupdate --list` runs twice, cache cleanup timeouts are an excessive 5 minutes, and there are two redundant `sudo -v` calls despite an active keepalive loop.

## Current State
- `check_system_load()` at lines 572–597: warns if 1-min load > 4.0; skippable via `skip_load_check=1`
- `backup_reminder()` at lines 236–281: polls Time Machine via `tmutil`; skippable via `skip_backup_warning=1`
- `replace_sysd()` at lines 711–717: dead code, hardcoded Docker systemd path, no known caller
- `softwareupdate --list` at lines 1091–1099: runs twice (preview + install), second invocation is redundant
- Cache cleanup timeout (lines 908–928): set to 300 seconds; most cache ops finish in <30s
- `~/Library/Caches` find (lines 906–931): no depth limit, scans deep into application data directories
- Stray `sudo -v` at lines 1168 and 1643: redundant with `keep_sudo_alive()` background loop already active

## Desired Outcome
- `check_system_load()` and its call site removed; `skip_load_check` env var removed from docs
- `backup_reminder()` and its call site removed; `skip_backup_warning` env var removed from docs
- `replace_sysd()` removed
- `softwareupdate --list` runs once; output reused for the install step
- Cache cleanup timeout reduced to 30 seconds
- `~/Library/Caches` find limited to `-maxdepth 3`
- Redundant `sudo -v` calls at lines 1168 and 1643 removed
- `test.sh` passes after all changes

## Approach
Remove the three functions and their call sites directly. For the softwareupdate fix, capture `--list` output in a variable and pass it to `--install`. Reduce the timeout constant. Add `-maxdepth 3` to the find call. Remove the two stray sudo -v lines.

## Scope
- **In**: `htotheizzo.sh` only — function removals, call site removals, timeout constant, find depth limit, redundant sudo -v
- **Out**: CLAUDE.md skip-flag documentation (low priority, tracked separately), GUI changes, Windows/Linux-specific code, adding new features

## Boundary Candidates
- Function removal (check_system_load, backup_reminder, replace_sysd)
- Performance fixes (softwareupdate dedup, timeout reduction, find depth)
- Credential hygiene (redundant sudo -v removal)

## Out of Boundary
- This spec does not add new cache cleanup commands (that is cache-cleanup spec)
- This spec does not change package manager update logic
- This spec does not touch test.sh beyond verifying it passes

## Upstream / Downstream
- **Upstream**: htotheizzo.sh as-is; no external dependencies
- **Downstream**: cache-cleanup spec depends on this completing first to avoid merge conflicts

## Existing Spec Touchpoints
- **Extends**: none (first spec)
- **Adjacent**: cache-cleanup touches the same file

## Constraints
- Must preserve `set -euo pipefail`
- Must not remove skip flags that are still used by other features
- test.sh must pass
