# Gap Analysis: sparkle-app-updates

## 1. Current State Investigation

### Host script (`htotheizzo.sh`, 1694 lines)
- **Strict mode**: `set -euo pipefail` (line 3). Non-interactive env exports at top (lines 5–8).
- **macOS update branch**: inside `update()`, gated by `[[ "$OSTYPE" == "darwin"* ]]` (line 991). Sequentially runs xcode-select, `update_homebrew true`, CocoaPods, `softwareupdate`, `mas upgrade` (line 1060–1063), Microsoft AutoUpdate, then maintenance helpers (`mac_disk_maintenance`, `clean_browser_caches`, `mac_system_maintenance`, `mac_spotlight_rebuild`, `mac_reset_launchpad`).
- **Helper-function pattern**: macOS feature blocks are extracted into `mac_*` / `update_*` functions defined *before* `update()` (e.g. `mac_disk_maintenance()` line 816), then called from the darwin branch with an explicit skip guard:
  ```bash
  if [[ -z "${skip_disk_maintenance:-}" ]]; then mac_disk_maintenance; else log "Skipped disk_maintenance"; fi
  ```
- **Skip convention**: `command_exists()` (line 136) auto-checks `skip_<normalized>` for *command-backed* tools. Feature blocks that are **not a single command** (disk_maintenance, spotlight, launchpad) use an explicit `[[ -z "${skip_x:-}" ]]` guard instead. Sparkle is a feature, not a command → use the explicit-guard pattern.
- **Failure model**: every fallible call ends `|| log "Warning: ..."`. `log()` (line 21) auto-appends any `Warning:`/`Error:` message to `ERROR_LOG`, which `show_error_summary()` (line 37) prints at the end of the run. No extra wiring needed for summary visibility.
- **Mock mode**: `MOCK_MODE` (line 13) + `maybe_run()` (line 64) log `[MOCK] Would run: ...` instead of executing.
- **GUI progress**: `progress "<label>"` (line 75) emits `PROGRESS:<label>` for the Electron GUI parser. macOS sections call it (e.g. line 993 "Updating macOS packages").
- **No existing Sparkle/appcast handling** anywhere (confirmed: zero matches).

### Dependency (`antares`, `/Users/yanick/Developer/2026/antares`)
- **`bin/update-app.sh <AppName|/path/App.app> [--dry-run]`** — the public, documented updater. Reads the app's `SUFeedURL`, fetches the appcast, selects newest **stable** version, and:
  - exits `0` as a **no-op** when already current (`installed ≥ stable`);
  - otherwise downloads → installs into `/Applications` (`cp -R`, no sudo) → **quits and relaunches** the app if it was running → clears antares' sparkle health-cache.
  - exits non-zero on: app not found, no `SUFeedURL`, appcast fetch failure, no `.app` in download.
  - `--dry-run` prints what it *would* do without installing.
- **`bin/outdated.sh`** has `_detail_sparkle()` that enumerates `/Applications/*.app`, filters by `SUFeedURL`, and prints only apps **behind** their appcast (`Name  cur → latest`). **But** this function is only reachable by *sourcing* `outdated.sh` (no `outdated.sh sparkle` subcommand; running it directly emits a full multi-source markdown report). Reusing it = coupling to antares private internals + executing its top-level setup on source.

## 2. Requirement-to-Asset Map

| Req | Need | Existing asset | Gap |
|-----|------|----------------|-----|
| 1 Discovery | Enumerate `/Applications/*.app`, keep those with `http(s)` `SUFeedURL` | Pattern mirrors antares `_detail_sparkle` loop (`defaults read "$app/Contents/Info" SUFeedURL`) | **Missing** — ~10-line loop, new code in htotheizzo |
| 2 Delegation | Update each discovered app | `update-app.sh` (public CLI, no-ops when current) | **Missing glue** — invoke per app |
| 3 antares resolution | Locate `update-app.sh`, skip if absent | none | **Missing** — `ANTARES_DIR` + default fallback + executable check |
| 4 skip_sparkle | Bypass section | explicit `[[ -z "${skip_x:-}" ]]` guard pattern | Trivial — reuse pattern |
| 5 Failure/summary | Per-app warning, continue, summary | `\|\| log "Warning:"` + `ERROR_LOG`/`show_error_summary` auto-wiring | **None** — use existing idiom |
| 6 Platform/non-interactive/mock/progress | darwin-only, no prompts, mock-safe, GUI label | `OSTYPE` branch, `progress()`, `MOCK_MODE`/`maybe_run()` | Mock strategy + running-app caveat (see Research Needed) |

## 3. Implementation Approach Options

### Option A — Reuse antares discovery by sourcing `outdated.sh`
Source `outdated.sh`, call `_detail_sparkle` to get only-outdated apps, then `update-app.sh` per app.
- ✅ No double appcast logic; gets pre-filtered outdated list.
- ❌ Couples to antares **private** functions; sourcing runs its top-level setup; fragile across antares versions; depends on output-format parsing.

### Option B — Lightweight discovery in htotheizzo + delegate to `update-app.sh` (recommended)
New `update_sparkle_apps()` helper: enumerate `/Applications/*.app`, filter by valid `SUFeedURL`, call `update-app.sh "<AppName>" || log "Warning: ..."` for each. Rely on `update-app.sh`'s built-in "already current → no-op" check instead of pre-filtering.
- ✅ Depends only on antares' **public, documented** `update-app.sh` contract (the script the user pointed to).
- ✅ ~30–40 lines mirroring `mac_disk_maintenance`; matches every htotheizzo convention.
- ✅ Resilient to antares internal changes.
- ❌ Calls `update-app.sh` for every Sparkle app, including up-to-date ones → one appcast fetch each (~bounded by app count, same network class as `mas`/`softwareupdate` already incur).

### Option C — Hybrid
Re-implement discovery (B) but additionally pre-check versions to skip up-to-date apps before invoking the updater.
- ✅ Avoids redundant fetches.
- ❌ Duplicates antares' version-comparison logic in htotheizzo (the exact thing Option B delegates) → more code, drift risk, for marginal network savings.

## 4. Effort & Risk

- **Effort: S (1–3 days)** — single new helper function + explicit skip guard + `progress` label, all on established patterns; touches only `htotheizzo.sh` (+ `CLAUDE.md`/`help` skip docs).
- **Risk: Low (integration) / Medium (delegated behavior)** — the htotheizzo glue is low-risk established-pattern work. Medium risk lives **outside our code**, in antares' behavior: it interrupts running apps and may fail to install apps whose `/Applications` bundle needs admin write. Both are surfaced as warnings, never aborts.

## 5. Recommendations for Design Phase

**Preferred approach: Option B.** A `update_sparkle_apps()` helper defined near `mac_disk_maintenance`, called from the darwin branch after the `mas`/Microsoft-AutoUpdate block, guarded by `[[ -z "${skip_sparkle:-}" ]]`, emitting a `progress "Updating Sparkle apps"` label, with each `update-app.sh` call wrapped in `|| log "Warning: ..."`.

### Key design decisions to settle
1. **Running-app interruption** (also Req 2.3): `update-app.sh` quits + relaunches running apps. Decide: (a) accept interruption (current auto-update intent), or (b) htotheizzo pre-checks `osascript "... is running"` and skips/defers running apps. Affects unattended-run friendliness.
2. **Mock-mode strategy** (Req 6.3): either (a) skip invocation entirely via `maybe_run`/`[MOCK]` log, or (b) pass `--dry-run` to `update-app.sh` (still does a network appcast fetch). For `test.sh` determinism, full skip (a) is safer.
3. **antares default location** (Req 3.2): `ANTARES_DIR` is primary; choose the canonical fallback. The dev path `~/Developer/2026/antares` is machine-specific; consider `${ANTARES_DIR:-$HOME/Developer/2026/antares}` plus an executable-check skip. Confirm with the user.
4. **Discovery scope**: antares scans only `/Applications`. Decide whether to also include `~/Applications` (parity vs. simplicity).

### Research Needed (defer to design / confirm)
- `/Applications` write-permission failures for admin-owned app bundles (antares `cp -R` runs without sudo) — confirm expected-warning behavior, not in scope to fix antares.
- Serialized network cost when many Sparkle apps are installed (each `update-app.sh` has a ~12s appcast timeout) — confirm acceptable vs. existing network-bound sections.

---

# Design Decisions & Synthesis (design phase)

**Discovery Scope**: Extension (light discovery). Integration into existing `htotheizzo.sh`; antares is an external, unmodified dependency.

## Synthesis Outcomes

- **Generalization**: The four open decisions collapse to one orchestration component with environment-driven knobs; no broader abstraction needed. `SPARKLE_APP_DIRS` generalizes "where to scan" (serves both the deferred `~/Applications` question and the test seam) without changing default behavior.
- **Build vs. Adopt**: **Adopt** antares `update-app.sh` for the per-app update (appcast read, version selection, download, install, relaunch). Building a second Sparkle updater inside htotheizzo was rejected — it would duplicate antares' logic and create drift. htotheizzo builds only the thin discovery + delegation loop.
- **Simplification**: No new files, no helper library, no version pre-check. Rely on `update-app.sh`'s built-in "already current → exit 0" no-op instead of htotheizzo comparing versions (Option C from gap analysis rejected as redundant).

## Design Decisions

### Decision: Discover in htotheizzo, delegate to antares' public CLI (Option B)
- **Alternatives**: (A) source antares `outdated.sh` and call private `_detail_sparkle`; (B) lightweight discovery in htotheizzo + per-app `update-app.sh`; (C) hybrid with version pre-check.
- **Selected**: B. Depend only on the documented `update-app.sh` contract.
- **Rationale**: A couples to antares private internals and its top-level side effects on source; C duplicates the exact version logic B delegates. B is the smallest stable surface.
- **Trade-offs**: B calls `update-app.sh` for every Sparkle app including up-to-date ones (one appcast fetch each), accepted as comparable to existing network-bound sections.
- **Follow-up**: Re-check if `update-app.sh` ever drops its no-op-when-current guarantee.

### Decision: Running apps are updated by default; opt out with `skip_sparkle_running=1`
- **Alternatives**: (a) always update (antares default: quit + relaunch); (b) always skip running apps; (c) configurable.
- **Selected**: c — default (a) to honor the user's explicit "auto-update all discovered apps" choice, with `skip_sparkle_running=1` to skip currently-running apps when interruption is unwanted (e.g. interactive daytime runs).
- **Rationale**: Cron/CI runs want everything updated; interactive runs may not want apps quit underneath them. The opt-out detects running state via `osascript` before delegating, since `update-app.sh` otherwise relaunches unconditionally.
- **Trade-offs**: Adds one env knob; without it set, a running app is quit/relaunched mid-session.

### Decision: Mock safety by gating the delegation call, not antares `--dry-run`
- **Alternatives**: (a) gate the `update-app.sh` invocation on `MOCK_MODE` (skip + log intent); (b) call `update-app.sh --dry-run`.
- **Selected**: a. Discovery (`defaults read`, read-only) still runs; the update call is skipped in mock.
- **Rationale**: antares `--dry-run` still performs a network appcast fetch → non-deterministic/slow for `test.sh`. Full skip keeps the suite hermetic and offline. Also add `skip_sparkle=1` to `run_htotheizzo_fast` so existing fast tests do not scan `/Applications`.

### Decision: antares location via `ANTARES_DIR`, default `$HOME/Developer/2026/antares`
- **Rationale**: `update-app.sh` lives in the antares **code repo**, not `~/antares` (the data store). The dev path is machine-specific but acceptable for a personal dotfiles tool; `ANTARES_DIR` makes it portable. Absent/non-executable updater → informational skip, never an error (3.3).
- **Follow-up**: Confirm the canonical default path with the user if antares moves.

## Risks & Mitigations
- Running-app interruption — mitigated by `skip_sparkle_running=1`.
- `/Applications` admin-write failures (antares `cp -R`, no sudo) — surface as non-aborting warnings; out of scope to fix antares.
- Serial appcast fetches with many Sparkle apps — accepted; parallelism deferred.
- antares CLI contract drift — captured as a Revalidation Trigger in design.md.
