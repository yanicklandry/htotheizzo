# Research & Design Decisions

## Summary
- **Feature**: `vendor-exclusion`
- **Discovery Scope**: Extension (existing `time-machine/` toolkit, read-only integration with antares)
- **Key Findings**:
  - antares' `category=dev` rows mix pure-cache roots (`~/.npm`, `~/.cache/uv`, `~/.nvm`, …) with mixed project-root trees (`developer` → `~/Developer`, `code` → `~/code`) that must never be wholesale-excluded.
  - antares' TSV rows carry alert *thresholds* (`amber_gb`/`red_gb`), not current folder sizes — there is no size column to "source" directly; actual current sizes live in `~/antares/folder-sizes.csv`, a file the PRD's declared 3-file data contract (Section 3) does not include.
  - htotheizzo already has an established convention for pointing at the antares repo (`ANTARES_DIR`, default `~/Developer/2026/antares`, used by `update_sparkle_apps()` in `htotheizzo.sh`) and for resolving the real user's home under `sudo` (`time-machine/setup.sh`'s `SUDO_USER`/`dscl` lookup, from commit `8c3b3cc`). Both are reused rather than re-invented.
  - antares' own launchd plists (`launchd/io.github.lenzai.antares.*.plist`) use a `__HOME__`/`__SCRIPT__`/`__PROG__` text-substitution template installed into `~/Library/LaunchAgents/`. htotheizzo has no launchd precedent of its own (only a cron-based `install_cron_job()` in `htotheizzo.sh`), so this feature adopts antares' template-substitution pattern under htotheizzo's own label namespace rather than inventing a different mechanism.
  - `tmutil isexcluded <path>` prints `[Excluded]  <path>` when already excluded (confirmed by direct invocation); `time-machine/setup.sh` already greps for this exact string, so the new script follows the same check.

## Research Log

### Antares TSV contract vs. actual on-disk shape
- **Context**: Requirement 1 depends on reading `watch-folders.tsv` + `watch-auto.tsv`; Requirement 5 depends on "sourcing sizes" from the same files.
- **Sources Consulted**: `~/Developer/2026/antares/watch-folders.tsv` (curated, read directly), `~/antares/watch-auto.tsv` (auto-discovered, read directly), `~/antares/` directory listing.
- **Findings**:
  - Column shape matches the PRD exactly: `name path amber_gb red_gb refresh_h [week_gb] [category] [method]`, tab-separated, `#`/blank lines skipped.
  - `category=dev` rows observed: `uv-cache`, `npm-cache`, `pnpm-store`, `homebrew-cache`, `xcode-derived` (curated); `nvm`, `dotlocal`, `coresimulator`, `docker`, `ms-playwright` (curated, added 14 Oct 2026); `developer` (`~/Developer`), `gradle` (auto-discovered).
  - `developer` and (separately observed) `code` are auto-discovered, tagged `category=dev` purely because they are large, not because they are pure caches — they are real project trees.
  - No column expresses current size; `amber_gb`/`red_gb` are alert thresholds. Current sizes live in `~/antares/folder-sizes.csv`, which the PRD's Section 3 data contract does not list.
- **Implications**: Requirement 5's "source sizes from antares' TSVs" is implemented as *sourcing the folder list to measure* from the TSVs (eliminating estimate.sh's independent discovery crawl), while the actual byte count still comes from a targeted `du` over that known, bounded list — not from `folder-sizes.csv`. This keeps the feature's antares dependency surface at exactly the 3 files the PRD declares. See Design Decision "Size sourcing scope" below.

### Mixed project-root folders in setup.sh's exclusion candidates
- **Context**: Section 4a of the PRD says estimate.sh/setup.sh should "source folder sizes... instead of running their own du sweep," but also says "no behavior change needed here beyond not duplicating antares' scan" — in tension with growing setup.sh's wholesale-exclusion list from antares data, which would be unsafe if it ever included `developer`/`code`.
- **Sources Consulted**: Direct inspection of `time-machine/setup.sh`'s existing `EXCLUDES` array; antares' `watch-folders.tsv`/`watch-auto.tsv` dev rows; user clarification (see Design Decision below).
- **Findings**: Several of setup.sh's existing hardcoded entries (`~/.npm`, `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/CoreSimulator`, `~/Library/Containers/com.docker.docker`) already correspond 1:1 to antares `category=dev` rows that are genuinely pure caches.
- **Implications**: Confirmed with the user — see Design Decision "setup.sh exclusion scope."

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Per-script duplicated TSV parsing | Each of exclude-vendor.sh/estimate.sh/setup.sh parses the TSVs inline | No new files | Triplicates fragile parsing logic; drift risk across 3 copies | Rejected |
| Shared `lib/` scripts sourced by callers | One `antares-folders.sh` + one `vendor-dirs.sh`, `source`d by all 4 scripts | Single source of truth for parsing, matching, and the pure-cache allow-list; matches existing shell-script-only stack (no new runtime dependency) | Adds 2 new files | **Selected** — smallest change that eliminates duplication (Build vs Adopt: adopt the existing `source`-a-helper-file bash idiom already implicit in the codebase's `if command_exists` helper style, no new abstraction layer) |
| Dedicated JSON/structured config instead of TSV | Introduce a new manifest format owned by htotheizzo | Easier parsing | Violates "no antares code changes," adds a translation step with no requirement demanding it | Rejected (speculative, not required) |

## Design Decisions

### Decision: Size sourcing scope for estimate.sh (Requirement 5)
- **Context**: antares' TSVs have no actual-size column; only `folder-sizes.csv` (undeclared dependency) has one.
- **Alternatives Considered**:
  1. Depend on `~/antares/folder-sizes.csv` for true zero-cost size reuse.
  2. Keep computing size via `du`, but scope the folder *list* to measure from antares' TSVs instead of an unbounded `$HOME`/`~/Developer` crawl.
- **Selected Approach**: (2). `estimate.sh` sources `lib/antares-folders.sh` to get the `category=dev` folder list, then reuses `lib/vendor-dirs.sh`'s matcher (the same one `exclude-vendor.sh` uses) to compute vendor/build byte totals via `du` over that bounded list.
- **Rationale**: Keeps the antares dependency surface at exactly the 3 files the PRD declares (Section 3); the PRD's own goal is eliminating duplicate *discovery*, not deduplicating the final `du` measurement.
- **Trade-offs**: `estimate.sh` still pays `du` cost on the known folders (not fully "free"), but no longer crawls `$HOME` to find them, and its vendor/build total now provably matches `exclude-vendor.sh --dry-run`'s total (Requirement 5.4) since both call the same shared function.
- **Follow-up**: If a future spec wants true zero-cost sizing, add `folder-sizes.csv` as a declared dependency then — not now.

### Decision: setup.sh exclusion scope (Requirement 5.2)
- **Context**: Antares' `category=dev` rows include mixed project-root trees (`developer`, `code`) that must never be wholesale-excluded from Time Machine, alongside genuine pure-cache roots.
- **Alternatives Considered**:
  1. No new exclusion paths — `setup.sh`'s hardcoded `EXCLUDES` array stays exactly as-is; only `estimate.sh`'s numbers change.
  2. Auto-add antares-sourced paths filtered through an explicit, manually-maintained allow-list of pure-cache row *names*.
- **Selected Approach**: (2), per user decision. `setup.sh` sources `lib/antares-folders.sh`, filters `category=dev` rows through a maintained `PURE_CACHE_ROW_NAMES` allow-list (e.g. `npm-cache`, `uv-cache`, `pnpm-store`, `homebrew-cache`, `xcode-derived`, `nvm`, `dotlocal`, `coresimulator`, `docker`, `ms-playwright`, `gradle`), and only appends allow-listed, resolved paths to its existing `EXCLUDES` array (deduplicated against the array's current hardcoded entries).
- **Rationale**: Lets `setup.sh` pick up new antares-discovered pure caches (e.g. a future `bun`/`rustup` row) without manual editing, while a hard, explicit allow-list makes it structurally impossible for a mixed tree like `developer`/`code` to be wholesale-excluded by accident.
- **Trade-offs**: The allow-list requires occasional manual maintenance as antares adds new pure-cache rows; accepted as the cost of safety.
- **Follow-up**: Revisit the allow-list whenever antares' `watch-folders.tsv`/`watch-auto.tsv` gain new `category=dev` rows.

### Decision: Scheduling mechanism — launchd, not cron
- **Context**: PRD explicitly rules out a persistent daemon and asks for a periodic sweep "matching antares' own launchd-triggered scripts" style; htotheizzo's own `install_cron_job()` uses cron instead.
- **Alternatives Considered**:
  1. Reuse htotheizzo's existing cron convention (`install_cron_job()`-style crontab entry).
  2. Adopt antares' launchd template-substitution pattern under htotheizzo's own label.
- **Selected Approach**: (2), per user decision (daily launchd).
- **Rationale**: launchd survives sleep/wake more reliably than cron on macOS and matches the sibling tool (antares) this feature is already coupled to; the PRD asked for this explicitly.
- **Trade-offs**: Introduces htotheizzo's first launchd plist, a new installation step distinct from `install_cron_job()`. Scoped as a single inline `--install-launchd` flag on `exclude-vendor.sh` rather than a separate installer script, since there is exactly one plist to manage (Simplification: antares needed a generic `bin/install.sh` because it manages five plists; one plist does not justify that layer here).

## Risks & Mitigations
- Risk: antares changes its TSV column order/shape in the future (it owns that file, per CLAUDE.md's "no antares code changes"). — Mitigation: `lib/antares-folders.sh` parses by fixed column position per the documented contract; Requirement 1.6's fallback path means a shape change that breaks parsing degrades to the hardcoded fallback list rather than failing hard.
- Risk: the `PURE_CACHE_ROW_NAMES` allow-list in `setup.sh` goes stale and misses new pure-cache rows antares adds later. — Mitigation: documented as a known follow-up in this file; failure mode is "doesn't auto-add a new cache" (safe), never "wholesale-excludes a project tree."
- Risk: `find_vendor_matches` traversal is slow on very large trees (e.g. `~/Developer`, `~/code`). — Mitigation: pruning at first match (Requirement 2.2) bounds the walk; this mirrors antares' own `disk-reclaim.sh` `du`-based sizing cost profile, which is already acceptable in production use.

## References
- `~/Developer/2026/antares/watch-folders.tsv` — curated folder-discovery contract (read-only).
- `~/antares/watch-auto.tsv` — machine-local auto-discovered overlay (read-only).
- `~/Developer/2026/antares/bin/disk-reclaim.sh` — source of the `--apply` / suggest-only-by-default convention this feature mirrors.
- `~/Developer/2026/antares/launchd/io.github.lenzai.antares.health.plist` — source of the launchd template-substitution pattern this feature adopts.
