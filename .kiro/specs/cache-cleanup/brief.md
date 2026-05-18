# Brief: cache-cleanup

## Problem
htotheizzo cleans caches for npm, Homebrew, Composer, and Pipenv, but misses equivalent documented cache-purge commands for pip, uv, docker builder layer cache, yarn (v1), and Cargo. These caches grow unboundedly and are legitimate maintenance targets — pip 20.1+ and uv both have explicit cache commands; Docker's builder cache is separate from `docker system prune`; yarn v1 and cargo accumulate registry/artifact caches over time.

## Current State
- pip: updated via `pip install --upgrade pip` but `pip cache purge` is never called
- uv: `uv self update` runs but `uv cache clean` is never called
- docker builder: `docker system prune -af --volumes` runs but leaves orphaned layer cache (builder cache requires `docker builder prune -f`)
- yarn (v1): `yarn global upgrade` runs but `yarn cache clean` is never called
- cargo: `rustup update` and `cargo install` run but registry/artifact cache is never purged

## Desired Outcome
After each tool's update block, the corresponding cache-purge command runs, following the existing pattern:
- gated on `command_exists`
- uses `|| log "Warning: ..."` fallback
- respects the tool's skip flag (e.g. `skip_pip=1` skips both the update and the cache purge)
- emits a `progress` event before running
- test.sh passes after changes

## Approach
For each tool, add the cache-purge command immediately after the existing update command in htotheizzo.sh, using the existing updater block pattern. Verify each command's correct flags against current documentation before adding.

Commands to add:
- `pip cache purge` (after pip update blocks)
- `uv cache clean` (after uv update block)
- `docker builder prune -f` (after docker system prune block)
- `yarn cache clean` (after yarn global upgrade block)
- `cargo cache --autoclean` if `cargo-cache` is installed, else skip silently (cargo has no built-in cache purge without the cargo-cache crate)

## Scope
- **In**: htotheizzo.sh — five cache-purge additions, each co-located with their tool's update block
- **Out**: Changing existing cache cleanup logic, adding new package managers, GUI changes, test.sh additions beyond pass verification

## Boundary Candidates
- pip cache purge (Python block)
- uv cache clean (uv block)
- docker builder prune (Docker block)
- yarn cache clean (yarn block)
- cargo cache autoclean (Rust block)

## Out of Boundary
- This spec does not modify how updates run, only adds cleanup after them
- This spec does not add new skip flags (reuses existing tool skip flags)
- This spec does not touch `~/Library/Caches` or system-level cleanup (that is script-cleanup)

## Upstream / Downstream
- **Upstream**: script-cleanup (same file, implement first to avoid conflicts)
- **Downstream**: none

## Existing Spec Touchpoints
- **Extends**: none
- **Adjacent**: script-cleanup touches the same file; implement after script-cleanup merges

## Constraints
- Must follow existing `command_exists` + `|| log "Warning: ..."` pattern exactly
- Must not add new top-level skip flags — reuse `skip_pip`, `skip_docker`, etc.
- `cargo cache` requires the `cargo-cache` crate; must be a soft check (silent skip if absent)
- test.sh must pass
