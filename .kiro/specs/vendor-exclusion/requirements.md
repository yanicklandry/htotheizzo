# Requirements Document

## Project Description (Input)
**Who:** Yanick, running htotheizzo's `time-machine/` backup toolkit on his own
Macs (some of which also run antares, `~/Developer/2026/antares`, owned by Fred).

**Current situation:** Time Machine currently backs up fully-reconstructible
dev-dependency directories (`node_modules`, `.venv`/`venv`, `target`, `dist`,
`build`, `.next`, `__pycache__`) — roughly 14 GB under `~/Developer` alone, over
half of that folder, plus another ~55 GB of regenerable caches disk-wide.
`time-machine/RECOMMENDATIONS.md` documents the exclusion list by hand and
points at Homebrew's `asimov` formula as a possible automated fix, but nothing
in htotheizzo actually automates exclusion today, and `estimate.sh`/`setup.sh`
re-derive folder sizes with their own independent `du` sweep even though
antares already tracks the same folders.

**What should change:**
- Add a new script, `time-machine/exclude-vendor.sh`, that reuses antares'
  existing folder discovery — `~/Developer/2026/antares/watch-folders.tsv`
  (curated, checked into antares) and `$ANTARES_HOME/watch-auto.tsv` (default
  `~/antares/watch-auto.tsv`, machine-local, auto-discovered) — filtered to
  `category=dev` rows for v1 (`category=ai` model-cache folders are explicitly
  out of scope for v1). It expands each row's `path` (`~/` and `$TMPDIR/`,
  literal expansion, no `eval`), finds `node_modules`/`.venv`/`venv`/`target`/
  `dist`/`build`/`.next`/`__pycache__` directories inside each (pruning at the
  first match, never descending into `.git`), and for each match calls
  `tmutil isexcluded` then `tmutil addexclusion` (no `sudo`, idempotent).
  Defaults to `--dry-run` (prints matches + total bytes, changes nothing); an
  `--apply` flag (mirroring antares' own `disk-reclaim.sh --apply` convention)
  performs the exclusion. It never excludes a watched folder's root itself,
  only matched subdirectories inside it.
- If `$ANTARES_HOME` or its TSVs are missing (antares not installed, or a
  different machine), the script must log a clear fallback message (e.g.
  "antares not found — scanning `~/Developer` directly instead") and continue
  using a hardcoded default folder list — never hard-fail.
- Run `exclude-vendor.sh --apply` via a daily `launchd` job (not a persistent
  watcher/daemon).
- Update `estimate.sh`/`setup.sh` to source folder sizes from antares'
  `watch-folders.tsv` + `watch-auto.tsv` (category `dev`) instead of running
  their own `du` sweep over `$HOME`, with the same antares-missing fallback
  behavior. Keep `RECOMMENDATIONS.md`'s existing exclusion-path table as the
  baseline list; keep the `asimov` mention as a fallback note for Macs without
  antares.
- Update `git-check.sh` to cross-reference the same vendor-dir match list used
  in `exclude-vendor.sh` so that `node_modules`/`.venv`/etc. are no longer
  reported as "untracked risk" alongside files that actually matter.
- No antares code changes of any kind, and nothing in this feature writes back
  into the antares repo or `$ANTARES_HOME` — the dependency on antares' TSV
  files is strictly read-only.

Full source PRD (for reference during requirements/design):
`/private/tmp/claude-501/-Users-yanick-Developer-2026-antares/c34066fa-04e0-4d2f-87ee-28ddeb8b3de4/scratchpad/htotheizzo-vendor-exclusion-PRD.md`

Decisions already made (do not re-litigate during requirements):
- Sweep cadence: **daily** launchd job.
- `category=ai` folders: **out of scope for v1** (dev-only).
- `RECOMMENDATIONS.md` asimov mention: **keep** as a fallback note for Macs
  without antares.

## Introduction

This feature adds automated Time Machine exclusion of reconstructible
vendor/build directories to htotheizzo's `time-machine/` toolkit, driven by
folder locations antares already discovers rather than an independent disk
scan. It covers a new sweep script, read-only reuse of two antares data files,
and two small adjustments to existing toolkit scripts (`estimate.sh`/`setup.sh`,
`git-check.sh`) so they agree with the sweep about what counts as reconstructible.

## Boundary Context

- **In scope**: discovering vendor/build directories inside antares'
  `category=dev` watched folders; dry-run reporting of matches and their size;
  applying Time Machine exclusions to those matches; a daily scheduled sweep;
  graceful fallback to a hardcoded folder list when antares data is absent;
  aligning `estimate.sh`/`setup.sh` sizing and `git-check.sh` risk reporting
  with the same match list.
- **Out of scope**: any change to antares itself or to files antares owns;
  any write-back into antares' repo or `$ANTARES_HOME`; `category=ai`
  (model-cache) folders; a persistent background watcher/daemon; scanning
  folders antares does not already track; replacing Homebrew's `asimov` as a
  general-purpose, system-wide solution.
- **Adjacent expectations**: this feature depends on antares'
  `watch-folders.tsv` and `watch-auto.tsv` already existing in their current,
  documented column shape and remaining readable local files; it does not
  require antares to run, to be healthy, or to be upgraded, and it must keep
  working (via fallback) if antares is not installed on a given machine.

## Requirements

### Requirement 1: Antares folder-list discovery
**Objective:** As a user of htotheizzo's Time Machine toolkit, I want the new
vendor sweep to reuse antares' already-known dev folder locations, so that I
don't pay for a second independent disk scan to find the same folders.

#### Acceptance Criteria
1. When the Vendor Exclusion Script runs, the Vendor Exclusion Script shall
   read `category=dev` rows from `~/Developer/2026/antares/watch-folders.tsv`
   and from `$ANTARES_HOME/watch-auto.tsv` (default `~/antares/watch-auto.tsv`
   when `$ANTARES_HOME` is unset).
2. When a folder name appears in both `watch-folders.tsv` and
   `watch-auto.tsv`, the Vendor Exclusion Script shall use the
   `watch-folders.tsv` entry for that folder and ignore the colliding
   `watch-auto.tsv` entry.
3. When a row's `path` field begins with `~/` or `$TMPDIR/`, the Vendor
   Exclusion Script shall expand it literally to the corresponding user home
   or temporary directory without evaluating the path as a shell expression.
4. The Vendor Exclusion Script shall skip blank lines and lines starting with
   `#` when reading either TSV file.
5. Where a row's `category` field is empty or not `dev`, the Vendor Exclusion
   Script shall exclude that row from the folders it scans in v1.
6. If `$ANTARES_HOME` is unset, is not a directory, or neither TSV file is
   readable, then the Vendor Exclusion Script shall print a message stating
   that antares was not found and that it is scanning a fallback folder list
   instead, and shall continue running using a hardcoded default folder list
   rather than exiting with an error.

### Requirement 2: Vendor/build directory detection
**Objective:** As a user, I want the sweep to find exactly the reconstructible
dev-dependency directories inside my watched folders, so that nothing that
matters gets excluded by mistake.

#### Acceptance Criteria
1. When scanning an expanded folder from Requirement 1, the Vendor Exclusion
   Script shall identify directories named `node_modules`, `.venv`, `venv`,
   `target`, `dist`, `build`, `.next`, or `__pycache__` as vendor/build
   matches.
2. When a vendor/build match is found, the Vendor Exclusion Script shall not
   descend further into that matched directory to look for nested matches.
3. The Vendor Exclusion Script shall never report or act on any path located
   inside a `.git` directory.
4. The Vendor Exclusion Script shall never identify the root of a watched
   folder itself (the expanded `path` from a TSV row) as a vendor/build
   match, only a matched subdirectory found inside it.

### Requirement 3: Dry-run reporting and exclusion application
**Objective:** As a user, I want to see what the sweep would do before it
changes anything, and then apply it deliberately, so that I stay in control of
what Time Machine stops backing up.

#### Acceptance Criteria
1. When the Vendor Exclusion Script runs without an explicit apply flag, the
   Vendor Exclusion Script shall default to dry-run mode.
2. While in dry-run mode, the Vendor Exclusion Script shall list every
   vendor/build match found and report the total bytes those matches occupy,
   and shall not change the Time Machine exclusion state of any path.
3. When the Vendor Exclusion Script runs with the apply flag, the Vendor
   Exclusion Script shall check whether each matched path is already excluded
   from Time Machine before deciding whether to exclude it.
4. If a matched path is already excluded from Time Machine, then the Vendor
   Exclusion Script shall skip that path without re-applying the exclusion.
5. If a matched path is not already excluded from Time Machine, then the
   Vendor Exclusion Script, in apply mode, shall exclude that path from Time
   Machine.
6. The Vendor Exclusion Script shall perform exclusion without requiring
   elevated (`sudo`) privileges.
7. When the Vendor Exclusion Script is run in apply mode twice in succession
   with no change in the underlying folders, the second run shall find no new
   paths requiring exclusion.

### Requirement 4: Scheduled execution
**Objective:** As a user, I want the sweep to keep up with new vendor/build
directories automatically, so that I don't have to remember to run it by hand.

#### Acceptance Criteria
1. The Vendor Exclusion Script shall be runnable on a recurring daily schedule
   without requiring a persistently running background process between runs.
2. The Vendor Exclusion Script shall produce the same result whether invoked
   by the scheduled run or manually from a terminal.

### Requirement 5: Backup-size estimation sourced from antares data
**Objective:** As a user running `estimate.sh`/`setup.sh`, I want folder-size
numbers for dev dependencies to come from antares' existing data, so that I
don't wait on a redundant `du` scan of the same folders.

#### Acceptance Criteria
1. When `estimate.sh` reports sizes for dev-dependency folders, `estimate.sh`
   shall source those sizes from the `category=dev` rows of antares'
   `watch-folders.tsv` and `watch-auto.tsv` instead of independently scanning
   `$HOME` with `du` for those same folders.
2. When `setup.sh` registers the recommended exclusion list, `setup.sh` shall
   source the corresponding folder locations from the same antares data used
   by `estimate.sh`.
3. If antares data is unavailable, then `estimate.sh` and `setup.sh` shall
   fall back to their existing hardcoded folder list and size behavior rather
   than failing.
4. The Vendor Exclusion Script's matches and `estimate.sh`'s sizing shall
   report byte totals that do not disagree for the same folder set on the same
   machine at the same point in time.

### Requirement 6: Untracked-risk reporting excludes vendor/build directories
**Objective:** As a user running `git-check.sh`, I want reconstructible
vendor/build directories left out of the "needs backup" findings, so that the
report highlights files that actually need a safety net.

#### Acceptance Criteria
1. When `git-check.sh` reports items that are not inside any git repository,
   `git-check.sh` shall exclude any item whose name matches the Requirement 2
   vendor/build match list from that report.
2. When `git-check.sh` reports untracked files inside a git repository,
   `git-check.sh` shall exclude any path whose name matches the Requirement 2
   vendor/build match list from that report.
3. The `git-check.sh` summary counts (items outside git, total bytes) shall
   not include any vendor/build match excluded under this requirement.

### Requirement 7: No impact on antares
**Objective:** As the owner of antares (Fred), I want this feature to never
modify anything antares owns, so that htotheizzo's new behavior carries zero
risk to antares' own data or operation.

#### Acceptance Criteria
1. The Vendor Exclusion Script shall only read from, and never write to,
   `watch-folders.tsv`, `watch-auto.tsv`, or any other file under the antares
   repository or `$ANTARES_HOME`.
2. `estimate.sh` and `setup.sh` shall only read from, and never write to, any
   file under the antares repository or `$ANTARES_HOME`.
