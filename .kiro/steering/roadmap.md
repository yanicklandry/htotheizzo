# Roadmap

## Overview
Improve htotheizzo's maintenance pass by removing noise features that aren't established best practices, eliminating dead code, fixing performance issues in the main script, and adding cache cleanup operations that are documented best practices but currently missing.

## Approach Decision
- **Chosen**: Two independent specs — `script-cleanup` (removals + performance fixes) and `cache-cleanup` (missing cache purge additions)
- **Why**: The two clusters have different risk profiles. Removals are low-risk and independently verifiable; cache additions need per-tool verification and may touch more code paths. Splitting keeps review clean and unblocks each group independently.
- **Rejected alternatives**: Single umbrella spec (harder to review atomically), direct implementation without specs (no review gate for cache additions)

## Scope
- **In**: Remove non-best-practice features (load check, backup reminder), remove dead code, fix performance issues (duplicate softwareupdate call, oversized timeouts, redundant sudo -v), add missing documented cache cleanup commands (pip, uv, docker builder, yarn, cargo)
- **Out**: GUI changes, new package manager support, Windows/Linux-specific improvements, architectural refactors

## Constraints
- All changes must preserve `set -euo pipefail` correctness
- All new cleanup commands must be gated on `command_exists` and use `|| log "Warning: ..."` fallback pattern
- Skip flags (`skip_<name>=1`) must continue to work for all affected sections
- test.sh must pass after changes

## Boundary Strategy
- **Why this split**: Removals (script-cleanup) can be implemented and reviewed without knowing anything about cache tool APIs; cache additions (cache-cleanup) require per-tool verification of correct commands and flags
- **Shared seams to watch**: Both specs touch htotheizzo.sh; implement script-cleanup first to reduce merge conflicts

## Specs (dependency order)
- [x] script-cleanup -- Remove load check, backup reminder, dead code; fix softwareupdate duplicate, cache timeouts, redundant sudo -v calls. Dependencies: none
- [x] cache-cleanup -- Add pip, uv, docker builder, yarn, cargo cache purge commands following existing patterns. Dependencies: script-cleanup
