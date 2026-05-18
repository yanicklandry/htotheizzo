# Project Structure

## Organization Philosophy

Flat and script-centric. The shell script is the primary artifact; everything else (GUI, docs, app bundle) is a companion. No build pipeline, no transpilation.

## Directory Patterns

### Root — scripts and docs
**Location**: `/`  
**Purpose**: Executable scripts and human-readable docs  
**Examples**: `htotheizzo.sh` (main), `htotheizzo-gui.sh` (GUI launcher), `update.sh` (Windows), `repair.sh` (macOS disk repair), `test.sh` (integration tests), `FUTURE.md` (backlog)

### GUI application
**Location**: `gui/`  
**Purpose**: Electron-based desktop GUI. Self-contained — `package.json`, `main.js` (main process), `preload.js` (context bridge), `renderer.js` (UI logic), `index.html` (layout/CSS)  
**Pattern**: All IPC flows through `preload.js`. GUI has no update logic — it delegates entirely to `htotheizzo.sh`.

### macOS app bundle
**Location**: `htotheizzo.app/`  
**Purpose**: Finder/Dock launchable `.app` wrapper. Must stay inside the repo; launcher resolves paths relative to the bundle location.

### Documentation
**Location**: `docs/`  
**Purpose**: Screenshots and supplementary docs

### Kiro spec-driven development
**Location**: `.kiro/`  
**Purpose**: AI-assisted SDLC — steering files (project memory), specs (per-feature requirements/design/tasks)  
**Pattern**: `steering/` is always-loaded project context; `specs/<feature>/` holds the 3-phase spec for individual features

### Claude skills
**Location**: `.claude/skills/`  
**Purpose**: Skill definitions (`SKILL.md`) invoked by Claude Code during development

## Naming Conventions

- **Shell scripts**: `kebab-case.sh`
- **GUI files**: `camelCase.js` / `index.html`
- **Skip variables**: `skip_<toolname>=1` (lowercase, underscore)
- **Progress events**: `PROGRESS:<human-readable label>` (uppercase prefix)

## Code Organization Principles

- **updater block pattern**: Each package manager follows `if command_exists <tool>; then log "..."; <update command> || log "Warning: ..."; fi`
- **OS branching**: macOS-specific blocks live inside `update_macos()`, Linux-specific in `update_linux()`, then both call `update()` for cross-platform managers
- **Skip guard**: `command_exists` already checks `skip_<name>` env vars — do not add redundant skip checks inside blocks

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
