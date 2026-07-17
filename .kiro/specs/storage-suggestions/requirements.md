# Requirements Document

## Project Description (Input)
Developers running htotheizzo reclaim only what the automatic cache purges (cache-cleanup spec) safely remove. The biggest disk hogs — ollama LLM models, Docker images/volumes, the Claude cache, package-manager stores, Xcode DerivedData — are left untouched because deleting them requires human judgment (which model/image to keep). Today there is no visibility into how much space these could free, so users never reclaim it.

htotheizzo should print a non-destructive "Reclaimable storage" summary at the end of a run. For each category it shows the reclaimable size and the exact command the user can copy/paste to reclaim it (e.g. `ollama rm llama3   →  4.7 GB`). Nothing is deleted automatically. Works identically in the CLI and shows through the GUI's output stream.

See `.kiro/specs/storage-suggestions/brief.md` for full discovery context (approach, scope, report contents, boundary candidates, and constraints).

## Introduction
This feature adds a read-only "Reclaimable storage" summary to the end of an htotheizzo run. It surveys disk-hungry categories that the automatic cache purges intentionally leave alone — because removing them requires human judgment about which items to keep — and reports how much space each holds plus the exact command to reclaim it. The user decides what to run; htotheizzo never deletes anything on their behalf.

## Boundary Context
- **In scope**: A report-only summary printed once near the end of a run, covering ollama models, Docker images/volumes, the Claude cache, npm/pnpm store, Xcode DerivedData, and `~/Library/Caches`; per-category size figures; per-category and overall reclaimable totals; exact, runnable removal commands; a single opt-out gate for the whole report; identical behavior in CLI and GUI output streams.
- **Out of scope**: Executing any removal command; deciding which model/image/cache entry is safe to delete; interactive prompts of any kind; new per-category removal skip flags; changes to the automatic cache-purge behavior owned by the `cache-cleanup` spec; Linux/Windows parity for this report.
- **Adjacent expectations**: This feature relies on the `cache-cleanup` spec's automatic purges having already run in the same pass, so the sizes it reports reflect post-purge disk state; it does not own or modify that purge behavior.

## Requirements

### Requirement 1: Reclaimable Storage Summary Presentation
**Objective:** As a developer running htotheizzo, I want a single reclaimable-storage summary at the end of my run, so that I can see at a glance how much disk space I could free without htotheizzo deleting anything for me.

#### Acceptance Criteria
1. When an htotheizzo run completes its maintenance pass, the Update Process shall print a "Reclaimable storage" summary before or alongside the run's final summary output.
2. The Update Process shall print the reclaimable storage summary at most once per run.
3. While the reclaimable storage summary is being generated, the Update Process shall not delete, move, or modify any file, cache entry, model, image, or volume.
4. The Update Process shall render the reclaimable storage summary using only output that displays correctly in both the CLI terminal and the GUI's output stream, with no terminal-only escape sequences that would corrupt the GUI's rendered output.
5. Where the `skip_storage_suggestions` gate is set, the Update Process shall omit the entire reclaimable storage summary from the run's output.

### Requirement 2: Per-Category Reclaimable Space Reporting
**Objective:** As a developer, I want each disk-hungry category (ollama models, Docker images/volumes, Claude cache, npm/pnpm store, Xcode DerivedData, `~/Library/Caches`) measured and reported individually, so that I know exactly which category is worth cleaning up.

#### Acceptance Criteria
1. Where a category's underlying tool, daemon, or path is present on the machine, the Update Process shall include that category in the reclaimable storage summary.
2. Where a category's underlying tool, daemon, or path is absent, the Update Process shall silently omit that category from the summary without producing an error or warning.
3. For each included category, the Update Process shall measure the reclaimable size using read-only operations that do not alter the measured category's state.
4. For the ollama and Docker categories, the Update Process shall report a size for each individual reclaimable item (e.g. each model, each dangling image) rather than only a combined figure.
5. If measuring the size of a category or item fails or produces no output, then the Update Process shall omit that entry from the summary rather than aborting the run or reporting an incorrect figure.

### Requirement 3: Reclaim Commands
**Objective:** As a developer, I want the exact command to reclaim each reported category or item, so that I can copy, paste, and run it myself without having to look up tool-specific syntax.

#### Acceptance Criteria
1. For each category or item included in the reclaimable storage summary, the Update Process shall print the exact, runnable command that reclaims that category's or item's space, requiring no edits before it can be run.
2. For the ollama and Docker categories, the Update Process shall pair each individually reported item with its own specific removal command, so the user can choose which items to remove.
3. The Update Process shall pair every reported size with its corresponding reclaim command on the same summary line or in clearly associated adjacent output.

### Requirement 4: Totals
**Objective:** As a developer, I want subtotal and overall totals, so that I can prioritize which categories are worth acting on.

#### Acceptance Criteria
1. When a category includes more than one reported item and size figures are available for those items, the Update Process shall print a category subtotal for that category.
2. When at least one category size is available, the Update Process shall print an overall total reclaimable size across all included categories.
3. If no category yields a measurable size, then the Update Process shall omit the reclaimable storage summary (or its totals line) rather than printing a zero or empty total.

## Requirement Traceability
All requirements above are new to this feature (`Extends: none`). Requirement 1 depends on the `cache-cleanup` spec's automatic purges having completed earlier in the same run so that reported sizes reflect post-purge state; this feature does not modify that purge behavior.
