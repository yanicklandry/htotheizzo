# Requirements Document

## Introduction

htotheizzo runs a comprehensive system update pass covering 60+ package managers and tools. Several of these tools — pip, uv, docker (builder), yarn (v1), and cargo — accumulate caches that grow unboundedly over time. While htotheizzo already updates these tools, it does not invoke their documented cache-purge commands. This spec adds the missing cache purge steps so that a single htotheizzo run also reclaims disk space from stale build artifacts, registry downloads, and layer caches.

## Prerequisites

> **IMPORTANT — Implementer prerequisite**: This spec assumes the **script-cleanup** spec has already been applied to `htotheizzo.sh` before any work in this spec begins. All insertion-point descriptions in the design and tasks documents are written relative to the post-script-cleanup state of the file. Applying cache-cleanup to the pre-cleanup script will produce merge conflicts and incorrect placement. Always merge script-cleanup first.

## Boundary Context

- **In scope**: Adding five cache-purge commands to `htotheizzo.sh`, each co-located with the tool's existing update block and following the established `command_exists` + `progress()` + `|| log "Warning: ..."` pattern.
- **Out of scope**: Changing existing update logic, adding new skip flags, modifying `~/Library/Caches` or system-level cleanup (that is script-cleanup), GUI changes, test.sh additions beyond verifying the script passes.
- **Adjacent expectations**: script-cleanup touches the same file and should be merged first to minimise conflicts. This spec does not extend or modify script-cleanup's changes; it only adds cache purge lines after existing update blocks.

## Requirements

### Requirement 1: pip cache purge

**Objective:** As a developer running htotheizzo, I want pip's download cache purged after the pip update block, so that stale wheel and HTTP caches are reclaimed without my manual intervention.

#### Acceptance Criteria

1. When the `pip` update block executes and `skip_pip` is not set, htotheizzo shall emit a `progress()` event and run `pip cache purge` immediately after the pip package-update logic, with `|| log "Warning: pip cache purge failed"` fallback.
2. When `skip_pip=1` is set, htotheizzo shall skip both the pip update and the pip cache purge.
3. If `pip` is not installed (`command_exists pip` is false), htotheizzo shall skip the pip cache purge silently.
4. When the `pip3` update block executes and `skip_pip3` is not set, htotheizzo shall emit a `progress()` event and run `pip3 cache purge` immediately after the pip3 package-update logic, with `|| log "Warning: pip3 cache purge failed"` fallback.
5. When `skip_pip3=1` is set, htotheizzo shall skip both the pip3 update and the pip3 cache purge.
6. If `pip3` is not installed (`command_exists pip3` is false), htotheizzo shall skip the pip3 cache purge silently.

### Requirement 2: uv cache clean

**Objective:** As a developer running htotheizzo, I want uv's package cache cleaned after the uv self-update block, so that stale downloaded packages do not consume disk space.

#### Acceptance Criteria

1. When the `uv` update block executes and `skip_uv` is not set, htotheizzo shall emit a `progress()` event and run `uv cache clean` immediately after the uv self-update logic, with `|| log "Warning: uv cache clean failed"` fallback.
2. When `skip_uv=1` is set, htotheizzo shall skip both the uv update and the uv cache clean.
3. If `uv` is not installed (`command_exists uv` is false), htotheizzo shall skip the uv cache clean silently.

### Requirement 3: docker builder prune

**Objective:** As a developer running htotheizzo, I want Docker's builder cache pruned after the docker system prune block, so that orphaned build layers are also reclaimed in a single pass.

#### Acceptance Criteria

1. When the `docker` cleanup block executes and the Docker daemon is running and `skip_docker` is not set, htotheizzo shall run `docker builder prune -f` immediately after `docker system prune`, with `|| log "Warning: docker builder prune failed"` fallback.
2. When `skip_docker=1` is set, htotheizzo shall skip both the docker system prune and the docker builder prune.
3. If the Docker daemon is not running, htotheizzo shall skip the docker builder prune (consistent with the existing `docker info` guard).
4. If `docker` is not installed (`command_exists docker` is false), htotheizzo shall skip the docker builder prune silently.

### Requirement 4: yarn cache clean

**Objective:** As a developer running htotheizzo, I want yarn's module cache cleaned after the yarn update block, so that the yarn v1 package cache does not grow unboundedly.

#### Acceptance Criteria

1. When the `yarn` update block executes and `skip_yarn` is not set, htotheizzo shall emit a `progress()` event and run `yarn cache clean` immediately after the yarn update logic, with `|| log "Warning: yarn cache clean failed"` fallback.
2. When `skip_yarn=1` is set, htotheizzo shall skip both the yarn update and the yarn cache clean.
3. If `yarn` is not installed (`command_exists yarn` is false), htotheizzo shall skip the yarn cache clean silently.

### Requirement 5: cargo cache autoclean (soft check)

**Objective:** As a developer running htotheizzo, I want the cargo registry and artifact cache auto-cleaned after the rustup/cargo update block, so that old build artifacts are reclaimed when the optional `cargo-cache` crate is available.

#### Acceptance Criteria

1. When the `cargo` block executes and `skip_cargo` / `skip_rustup` is not set and `cargo-cache` is installed (i.e., `cargo cache` resolves as a cargo subcommand), htotheizzo shall emit a `progress()` event and run `cargo cache --autoclean` with `|| log "Warning: cargo cache autoclean failed"` fallback.
2. When `skip_cargo=1` or `skip_rustup=1` is set, htotheizzo shall skip the cargo cache autoclean.
3. If `cargo-cache` is not installed (the `cargo cache` subcommand is absent), htotheizzo shall skip silently — no warning, no error.
4. If `cargo` is not installed (`command_exists cargo` is false), htotheizzo shall skip the cargo cache autoclean silently.

### Requirement 6: Pattern conformance

**Objective:** As a maintainer of htotheizzo, I want all new cache-purge additions to follow the established updater block patterns, so that the codebase remains internally consistent and future contributors can follow the same conventions.

#### Acceptance Criteria

1. The htotheizzo script shall emit a `progress()` call before each cache-purge operation (where a progress event is appropriate for the block's scope).
2. Each cache-purge command shall use the `|| log "Warning: ..."` fallback pattern to avoid aborting the entire run on failure.
3. No new top-level `skip_*` environment variables shall be introduced; existing tool skip flags shall be reused.
4. All cache-purge additions shall be gated on `command_exists` (or equivalent runtime check) consistent with the rest of the script.
5. The script shall pass `test.sh` after all additions are applied.
