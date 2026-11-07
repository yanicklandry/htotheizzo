# Implementation Plan: vendor-exclusion

- [ ] 1. Foundation: shared libraries for antares folder discovery and vendor directory matching
- [x] 1.1 Implement antares folder-discovery library (lib/antares-folders.sh)
  - `read_dev_folders` core logic: parse both TSVs, filter to `category=dev`, dedup with curated rows winning on name collision, expand `~/` and `$TMPDIR/` path prefixes literally (never `eval`)
  - Fallback path: when neither TSV is readable, logs a fallback notice to stderr and returns a hardcoded fallback folder list instead of failing
  - Never opens any antares-owned path for writing
  - Observable completion: running the function against a temp fixture with two TSVs produces deduped name/path rows on stdout; with no fixture present, it produces the fallback notice on stderr plus the fallback row on stdout
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 7.1_

- [x] 1.2 (P) Implement vendor-directory matching library (lib/vendor-dirs.sh)
  - Canonical list of the 8 vendor/build directory names (`node_modules`, `.venv`, `venv`, `target`, `dist`, `build`, `.next`, `__pycache__`)
  - `find_vendor_matches`: walks a given root, prunes at the first match (no descending into a matched directory), excludes anything under a `.git` directory, never returns the scanned root itself
  - `is_vendor_dir_path`: name-based check sharing the same canonical list, for callers that filter a path list rather than walk a root
  - Observable completion: against a fixture tree with a nested `dist/node_modules` and a `.git/node_modules`, the matcher returns only the outer `dist` and omits the `.git`-contained path
  - _Requirements: 2.1, 2.2, 2.3, 2.4_
  - _Boundary: lib/vendor-dirs.sh_

- [x] 1.3 Smoke-test both shared libraries against fixture trees
  - Fixture TSVs covering: a name collision between a curated and an auto row, a row with `category` other than `dev`, and a row with a fractional threshold value
  - Fixture directory tree exercising the `find_vendor_matches` edge cases from 1.2
  - Cross-check that `is_vendor_dir_path` agrees with `find_vendor_matches` on the same fixture tree
  - Observable completion: a documented test run shows every fixture assertion passing — collision resolves to the curated row, the non-dev row is excluded, the fractional row is skipped, `.git` exclusion holds, and the root is never returned
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4_
  - _Depends: 1.1, 1.2_

- [ ] 2. Core: exclude-vendor.sh sweep script
- [ ] 2.1 Implement dry-run sweep (default mode)
  - CLI parses `--dry-run` (default), `--apply`, and `--help`; an unrecognized flag prints usage and exits non-zero
  - Calls `read_dev_folders` then `find_vendor_matches` per returned folder, skipping any folder path that doesn't exist on disk
  - Prints the full match list and total bytes; performs no `tmutil` mutation while in dry-run
  - Observable completion: running `exclude-vendor.sh` with no flags against a fixture containing known vendor dirs prints the matches and a non-zero total, and a follow-up `tmutil isexcluded` check confirms nothing was actually excluded
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2_
  - _Depends: 1.1, 1.2_

- [ ] 2.2 Implement apply mode with idempotent exclusion
  - `--apply` checks `tmutil isexcluded` for each match before calling `tmutil addexclusion`; already-excluded matches are skipped and counted separately from newly-excluded ones
  - No `sudo` is required or attempted anywhere in the script
  - Prints a summary of excluded count, skipped count, and total bytes
  - Observable completion: the first `--apply` run against a fixture excludes N matches and reports N excluded / 0 skipped; a second consecutive `--apply` run against the same fixture reports 0 excluded / N skipped
  - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 2.3 Add launchd daily-schedule template, self-install flag, and toolkit documentation update
  - New `launchd/io.github.yanicklandry.htotheizzo.exclude-vendor.plist.template` using `__HOME__`/`__SCRIPT__`/`__PROG__` substitution (the pattern antares' own plists use), with a daily `StartCalendarInterval`
  - `--install-launchd` flag resolves the script's own path, substitutes the template, writes the result to `~/Library/LaunchAgents/`, and loads it via `launchctl`, unloading first if already installed so re-installs stay idempotent
  - Scheduled run's stdout/stderr route to `~/logs/htotheizzo-exclude-vendor.{out,err}.log`, matching htotheizzo's existing `~/logs/` convention
  - Add `exclude-vendor.sh` to `time-machine/RECOMMENDATIONS.md`'s toolkit table and reframe its existing Homebrew `asimov` mention as the fallback option for Macs without antares installed
  - Observable completion: running `exclude-vendor.sh --install-launchd` twice in a row leaves exactly one loaded launchd job (verifiable via `launchctl list`) pointed at the script's resolved path, and `RECOMMENDATIONS.md` lists the new script alongside the reframed `asimov` note
  - _Requirements: 4.1, 4.2_
  - _Depends: 2.1, 2.2_

- [ ] 3. Integration: align estimate.sh, setup.sh, and git-check.sh with the shared vendor-dir match list
- [ ] 3.1 (P) Source estimate.sh's dev-folder sizing from the shared libraries
  - Replace the unbounded `$HOME`-wide `node_modules` find with `find_vendor_matches` over `read_dev_folders`' output for the "Excluded: caches and build tools" row
  - Replace the hardcoded `DEV_DIRS` array with `read_dev_folders`' output for the "Developer folder" breakdown section; `GENERATED_PATTERNS` and every other row/section are unchanged
  - Antares-absent behavior relies entirely on `read_dev_folders`' own fallback (no separate fallback branch added in `estimate.sh`); never opens an antares-owned path for writing
  - Observable completion: calling the shared `find_vendor_matches`/`read_dev_folders` functions directly with the same folder set `estimate.sh` now sources produces the same byte total as the row `estimate.sh` prints (full cross-script agreement against the `exclude-vendor.sh` CLI is re-verified end-to-end in task 4.1); with antares data removed, `estimate.sh` still completes and reports using the fallback folder
  - _Requirements: 5.1, 5.3, 5.4, 7.2_
  - _Boundary: estimate.sh_
  - _Depends: 1.1, 1.2_

- [ ] 3.2 (P) Gate setup.sh's antares-sourced exclusions behind a pure-cache allow-list
  - Add a `PURE_CACHE_ROW_NAMES` allow-list and call `read_dev_folders` with the already-resolved `USER_HOME` (the existing `sudo`-aware resolution), never with raw `$HOME`
  - Only allow-listed row names' resolved paths are merged (deduplicated against existing entries) into the existing `EXCLUDES` array before the existing exclusion loop runs
  - Antares-absent behavior leaves `EXCLUDES` exactly as it is today — no additions, no error
  - Observable completion: with antares data present, inspecting the final `EXCLUDES` array before the exclusion loop shows allow-listed pure-cache paths added, and confirms `developer`/`code` paths are absent even though both are `category=dev` rows
  - _Requirements: 5.2, 5.3, 7.2_
  - _Boundary: setup.sh_
  - _Depends: 1.1_

- [ ] 3.3 (P) Filter git-check.sh's untracked-risk reports by the vendor-dir match list
  - "Items NOT in any git repo" loop skips any item whose basename matches `is_vendor_dir_path`
  - "Untracked files inside git repos" loop filters listed paths through the same check before printing or counting them
  - Summary counts (items outside git, total bytes) reflect the filtered results
  - Observable completion: running `git-check.sh` against a fixture directory containing a non-git `node_modules` folder and a git repo with an untracked `build/` folder shows neither one in either report section or in the summary counts
  - _Requirements: 6.1, 6.2, 6.3_
  - _Boundary: git-check.sh_
  - _Depends: 1.2_

- [ ] 4. Validation: cross-script end-to-end checks
- [ ] 4.1 Validate full antares-present sweep end to end
  - Run `exclude-vendor.sh --dry-run` then `--apply` against a real antares-tracked dev folder subtree, cross-checking the total against `estimate.sh`'s vendor/build row and spot-checking matched paths with `tmutil isexcluded`
  - Confirm a second consecutive `--apply` run is a no-op
  - Observable completion: a documented run transcript shows the dry-run total matching both the apply-mode excluded total and `estimate.sh`'s row, zero new exclusions on rerun, and `tmutil isexcluded` confirming each matched path
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 5.4_
  - _Depends: 2.1, 2.2, 3.1_

- [ ] 4.2 Validate antares-absent fallback end to end across all three antares-dependent scripts
  - With the antares repo path and `$ANTARES_HOME` pointed at an empty/missing location, run `exclude-vendor.sh`, `estimate.sh`, and `setup.sh` and confirm each degrades per its documented fallback (the first two log the fallback notice and use the hardcoded list; `setup.sh` silently keeps its current `EXCLUDES` array) rather than failing
  - Observable completion: all three scripts exit successfully, with output matching the documented fallback behavior for each
  - _Requirements: 1.6, 5.3_
  - _Depends: 2.1, 3.1, 3.2_

## Implementation Notes
- 1.3 reviewer follow-up (non-blocking): `smoke-test.sh`'s comment/blank-line fixture lines don't actually regression-test the skip logic (the awk empty-field filter coincidentally absorbs them even with the explicit skip-check removed); no fixture exercises "one TSV present, the other missing"; `mktemp -d`'s exit code isn't checked. None required by design.md's Testing Strategy — noted here for optional future hardening.
