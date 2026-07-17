# Requirements Document

## Project Description (Input)
Developers running htotheizzo reclaim only what the automatic cache purges (cache-cleanup spec) safely remove. The biggest disk hogs — ollama LLM models, Docker images/volumes, the Claude cache, package-manager stores, Xcode DerivedData — are left untouched because deleting them requires human judgment (which model/image to keep). Today there is no visibility into how much space these could free, so users never reclaim it.

htotheizzo should print a non-destructive "Reclaimable storage" summary at the end of a run. For each category it shows the reclaimable size and the exact command the user can copy/paste to reclaim it (e.g. `ollama rm llama3   →  4.7 GB`). Nothing is deleted automatically. Works identically in the CLI and shows through the GUI's output stream.

See `.kiro/specs/storage-suggestions/brief.md` for full discovery context (approach, scope, report contents, boundary candidates, and constraints).

## Requirements
<!-- Will be generated in /kiro-spec-requirements phase -->
