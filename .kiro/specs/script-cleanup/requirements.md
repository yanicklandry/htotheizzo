# Requirements Document

## Introduction

htotheizzo is a single-command system updater that runs all package managers and development tools in one pass. The main script (`htotheizzo.sh`) currently includes non-best-practice features that add noise and latency to every run: a load average check (`check_system_load`) that warns at load > 4.0, and a backup reminder (`backup_reminder`) that polls Time Machine status. Dead code (`replace_sysd()`) is also present. Additionally, `softwareupdate --list` runs twice, cache cleanup timeouts are an excessive 5 minutes (300 s), and there are two redundant `sudo -v` calls despite an active keepalive loop. This spec covers removing or fixing all of these issues so every update run is leaner and faster.

## Boundary Context

- **In scope**: Removing `check_system_load()`, `backup_reminder()`, and `replace_sysd()` (functions + call sites); deduplicating the `softwareupdate --list` invocation; reducing cache cleanup timeout from 300 s to 30 s; adding `-maxdepth 3` to the `~/Library/Caches` find call; removing the two stray `sudo -v` lines. All changes are in `htotheizzo.sh` only.
- **Out of scope**: CLAUDE.md skip-flag documentation updates, GUI changes, Windows/Linux-specific code paths, adding new cache cleanup commands (covered by the cache-cleanup spec), changes to `test.sh` logic.
- **Adjacent expectations**: The cache-cleanup spec depends on this spec completing first to avoid merge conflicts in `htotheizzo.sh`.

## Requirements

### Requirement 1: Remove check_system_load

**Objective:** As a developer running htotheizzo, I want the load average check removed, so that every run is not slowed down or cluttered by an informational warning that is not an established best practice.

#### Acceptance Criteria

1. When htotheizzo runs, the htotheizzo script shall not execute any load average check or emit any load average log lines.
2. The htotheizzo script shall not define a `check_system_load` function.
3. The htotheizzo script shall not contain a call site to `check_system_load`.
4. The htotheizzo script shall not reference the `skip_load_check` environment variable.

### Requirement 2: Remove backup_reminder

**Objective:** As a developer running htotheizzo, I want the backup reminder removed, so that every run is not slowed down or cluttered by Time Machine polling that is not an established best practice.

#### Acceptance Criteria

1. When htotheizzo runs, the htotheizzo script shall not execute any backup reminder or emit any backup-reminder log lines.
2. The htotheizzo script shall not define a `backup_reminder` function.
3. The htotheizzo script shall not contain a call site to `backup_reminder`.
4. The htotheizzo script shall not reference the `skip_backup_warning` environment variable.

### Requirement 3: Remove replace_sysd dead code

**Objective:** As a maintainer of htotheizzo, I want the `replace_sysd` dead code removed, so that the script does not contain unreachable code paths that could confuse future contributors.

#### Acceptance Criteria

1. The htotheizzo script shall not define a `replace_sysd` function.
2. The htotheizzo script shall not contain any call site to `replace_sysd`.

### Requirement 4: Deduplicate softwareupdate --list

**Objective:** As a developer running htotheizzo on macOS, I want `softwareupdate --list` to execute only once per run, so that the macOS update step does not incur the latency of a redundant network call.

#### Acceptance Criteria

1. When htotheizzo runs on macOS with softwareupdate available, the htotheizzo script shall invoke `softwareupdate --list` exactly once per run.
2. When htotheizzo runs on macOS and `softwareupdate --list` output is available, the htotheizzo script shall reuse that output for logging the available update list rather than re-fetching it.

### Requirement 5: Reduce cache cleanup timeout

**Objective:** As a developer running htotheizzo on macOS, I want the cache cleanup timeout reduced to 30 seconds, so that the maintenance phase does not block the run for up to 5 minutes when cache files are numerous.

#### Acceptance Criteria

1. When htotheizzo performs cache cleanup on macOS, the htotheizzo script shall apply a maximum timeout of 30 seconds to the find-and-delete operation.
2. If the cache cleanup operation exceeds 30 seconds, the htotheizzo script shall log a warning and continue without aborting the run.

### Requirement 6: Limit cache find depth

**Objective:** As a developer running htotheizzo on macOS, I want the `~/Library/Caches` find call limited to a maximum depth of 3, so that the operation does not scan deeply into application data directories and incur unnecessary I/O.

#### Acceptance Criteria

1. When htotheizzo performs cache cleanup on macOS, the htotheizzo script shall pass `-maxdepth 3` to the find call that scans `~/Library/Caches`.
2. The htotheizzo script shall apply the depth limit consistently across all code paths (gtimeout branch, timeout branch, and fallback branch).

### Requirement 7: Remove redundant sudo -v calls

**Objective:** As a developer running htotheizzo, I want the two stray `sudo -v` calls removed, so that the script does not redundantly refresh sudo credentials when the `keep_sudo_alive()` keepalive loop is already active.

#### Acceptance Criteria

1. The htotheizzo script shall not contain a standalone `sudo -v` call at the position previously following the OS branch block (near line 1168).
2. The htotheizzo script shall not contain a standalone `sudo -v` call at the position previously preceding the gem update block (near line 1643).
3. While `keep_sudo_alive()` is active, the htotheizzo script shall rely exclusively on the keepalive loop to maintain sudo credentials.

### Requirement 8: Test suite passes

**Objective:** As a maintainer of htotheizzo, I want `test.sh` to pass after all changes, so that the cleanup does not introduce regressions in any testable behavior.

#### Acceptance Criteria

1. When `./test.sh` is executed after all changes, the test suite shall exit with code 0.
2. If any test in `test.sh` fails after the changes, the htotheizzo script shall be considered non-compliant with this specification.
