# Brief: storage-suggestions

## Problem
Developers running htotheizzo reclaim only what the automatic cache purges (cache-cleanup spec) safely remove. The biggest disk hogs — ollama LLM models, Docker images/volumes, the Claude cache, package-manager stores, Xcode DerivedData — are left untouched because deleting them requires human judgment (which model/image to keep). Today there is no visibility into how much space these could free, so users never reclaim it.

## Current State
- `htotheizzo.sh` has `check_disk_space()`, `estimate_update_sizes()`, and `show_error_summary()` helpers, plus `progress()`/`log()`.
- The `update()` orchestrator (line ~1116) runs the full pass and ends without a storage-reclaim summary.
- Docker cleanup exists (~line 1527: `docker system prune -af --volumes`) but only as an automatic purge, not a "here's what large images you could remove" report.
- **ollama is not referenced anywhere in the script.**
- The `cache-cleanup` spec adds automatic, unconditional cache purges co-located with each tool's update block — a different interaction model from this feature.

## Desired Outcome
At the end of a run, htotheizzo prints a non-destructive "Reclaimable storage" summary. For each category it shows the reclaimable size and the exact command the user can copy/paste to reclaim it (e.g. `ollama rm llama3   →  4.7 GB`). Nothing is deleted automatically. Works identically in the CLI and shows through the GUI's output stream.

## Approach
Report-only storage advisor. Add a `suggest_storage_savings()` function (macOS-focused, `command_exists`/daemon-gated per tool) called near the end of `update()`, after maintenance and before/alongside the final summary. Each category probes sizes with read-only commands and prints a right-sized suggestion line with the precise removal command. No prompts, no deletion, no new skip-flag semantics for removal (a single `skip_storage_suggestions=1` may gate the whole report).

## Scope
- **In**:
  - A report-only `suggest_storage_savings()` section printed at end of run.
  - Categories: ollama models (`ollama ls` sizes → `ollama rm <model>`), Docker images/volumes (`docker system df` / `docker images` → prune/remove commands), Claude cache (`~/.claude` cache size), npm/pnpm store, Xcode DerivedData, `~/Library/Caches` total size.
  - Per-category `command_exists`/daemon/path guards; silent skip when a tool/path is absent.
  - Human-readable sizes and copy-pasteable exact commands.
  - Optional single gate flag `skip_storage_suggestions=1`.
- **Out**:
  - Any automatic deletion of models/images/caches (that judgment stays with the user).
  - Interactive y/N prompts (explicitly rejected: TTY + GUI complexity, accidental-deletion risk).
  - Changes to the automatic cache-purge logic owned by `cache-cleanup`.
  - New per-tool removal skip flags.
  - GUI-specific UI beyond what already renders the script's stdout.

## Report Contents (per suggestion — required)
Every suggestion line MUST show both:
1. **Space that would be saved** — the reclaimable size, measured with read-only probes and shown in human-readable units (e.g. `4.7 GB`, `312 MB`). Where a total isn't cheaply available, show the best obtainable figure (per-item sizes and/or a category subtotal) rather than omitting the number.
2. **Exact command(s) to run** — the precise, copy-pasteable command that reclaims that space, runnable as-is with no editing (e.g. `ollama rm llama3`, `docker image prune -a`, `rm -rf ~/Library/Developer/Xcode/DerivedData`). For per-item categories (ollama models, docker images), list the individual removal commands with each item's size so the user can pick.

Example lines:
```
ollama    llama3:70b        39 GB   →  ollama rm llama3:70b
ollama    mistral:7b         4.1 GB →  ollama rm mistral:7b
docker    dangling images   6.3 GB  →  docker image prune -f
xcode     DerivedData       12 GB   →  rm -rf ~/Library/Developer/Xcode/DerivedData
──────────────────────────────────────────
Total reclaimable: ~61 GB
```
A category total and an overall "Total reclaimable" figure SHALL be printed when sizes are available.

## Boundary Candidates
- Size-probing per category (read-only measurement) vs. suggestion rendering (formatting + command strings) — clean seam, testable independently.
- Category registry (which tools, their probe + suggest commands) vs. the orchestrating `suggest_storage_savings()` driver.
- Placement/ordering within `update()` and interaction with the existing summary/error-summary output.

## Out of Boundary
- Executing any removal command.
- Deciding retention policy (which model/image is "stale").
- Cross-platform (Linux) parity beyond incidental reuse; this is macOS-focused like the rest of the maintenance sections.

## Upstream / Downstream
- **Upstream**: existing helpers `command_exists`, `progress`, `log`, `check_disk_space`, and the `update()` orchestrator; the docker guard pattern (`docker info`) already in the script; the `cache-cleanup` spec (runs its automatic purges first, so this report reflects post-purge state).
- **Downstream**: possible future interactive/GUI "reclaim" action that would consume the same category registry; GUI could later surface these suggestions as buttons.

## Existing Spec Touchpoints
- **Extends**: none (new section; does not modify `cache-cleanup` blocks).
- **Adjacent**: `cache-cleanup` (automatic safe purges — must run before this report so sizes are accurate), `script-cleanup` (both touch `htotheizzo.sh`; add this section after those land to avoid conflicts).

## Constraints
- Preserve `set -euo pipefail` correctness; all probes must tolerate missing tools/empty output without aborting the run (`|| true` / guarded).
- All categories gated on `command_exists` (and daemon/path checks where relevant); absent tool = silent skip.
- Read-only only: the report must never mutate state.
- Must render cleanly through the GUI's stdout stream (no TTY-only escape sequences that break the Electron output view).
- Sizes shown in human-readable units; commands shown must be exactly runnable as-is.
