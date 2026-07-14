# Research & Design Decisions

## Summary
- **Feature**: `cache-cleanup`
- **Discovery Scope**: Simple Addition (five co-located line-group insertions into an existing flat sequential shell script)
- **Key Findings**:
  - `htotheizzo.sh` gates every updater block with `command_exists <tool>`, which itself checks `skip_<tool>` and `only_<tool>` before probing `command -v`. Placing a purge line inside that guard is automatically skip-flag- and install-gated; no new skip variables or inline checks are needed (Req 6.3, 6.4).
  - All six insertion anchors named in the design exist verbatim in the current post-`script-cleanup` script, so the design's placement instructions are directly executable.
  - The cargo soft-check reuses the crate-list idiom already present in the same block, so no new detection pattern is introduced (Req 5.3).

## Research Log

### Verifying insertion anchors against the live script
- **Context**: The design specifies precise insertion points relative to the post-`script-cleanup` state of `htotheizzo.sh`. `script-cleanup` is recorded as complete in the pipeline queue, so the anchors had to be confirmed against the real file.
- **Sources Consulted**: `htotheizzo.sh` (grep of pip/pip3/uv/docker/yarn/cargo blocks and helper functions).
- **Findings**:
  - `command_exists()` at line 159 checks `skip_<tool>` (normalizing hyphens to underscores) and `only_<tool>` mode before the `command -v` probe.
  - pip block ends with `export PIP_REQUIRE_VIRTUALENV=true` (line 1426); pip3 mirrors it (line 1454).
  - uv block: `uv self update || log ...` (line 1648) precedes the closing `fi`.
  - docker: `docker system prune -af --volumes || log ...` (line 1525) sits inside the `if ! docker info ...; else` daemon-running guard; the `podman` branch is separate and correctly excluded.
  - yarn: multiple update branches (corepack / npm / global upgrade) converge before the closing `fi`.
  - cargo: block captures `cargo_installed=$(cargo install --list)` (line 1475) and greps it for `cargo-update`; the same variable can be re-grepped for `cargo-cache`.
- **Implications**: Every design anchor is real and unambiguous. The cargo detection can reuse the already-captured `cargo_installed` variable rather than re-invoking `cargo install --list`, a minor implementation refinement fully within the design's intent.

### command_exists skip-flag semantics
- **Context**: The prior design draft contained a self-contradictory paragraph about whether `command_exists` checks skip flags.
- **Sources Consulted**: `htotheizzo.sh:159-182`.
- **Findings**: `command_exists` returns 1 (skip) when `skip_<tool>` is set, satisfying the "skip both update and purge" acceptance criteria purely by placement inside the guard.
- **Implications**: Corrected the Overview/Existing Architecture Analysis paragraph so the design accurately states the guard behavior. No inline skip checks required for any of the five additions.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Co-located line-group insertion | Add each purge line immediately after its tool's existing update commands, inside the existing guard | Zero new abstractions; inherits skip/install gating; minimal diff | Placement must track upstream block restructuring | Chosen — matches the script's flat sequential convention |
| Centralized purge function | Collect all purges into one new `purge_caches()` function | Single call site | Duplicates guard logic; diverges from per-tool block convention | Rejected — over-engineered for five lines |

## Design Decisions

### Decision: cargo-cache detection via crate-list grep
- **Context**: `cargo cache --autoclean` requires the optional `cargo-cache` crate; Req 5.3 mandates a silent skip when it is absent.
- **Alternatives Considered**:
  1. Probe with `cargo cache --list-top-items &>/dev/null` — fails fast but introduces a detection idiom not used elsewhere.
  2. Grep the installed crate list (`cargo install --list | grep -q "cargo-cache"`) — the exact idiom the same block already uses for `cargo-update`.
- **Selected Approach**: Grep the crate list (reusing the already-captured `cargo_installed`).
- **Rationale**: Internal consistency with the existing cargo-update guard; avoids invoking an unknown subcommand.
- **Trade-offs**: A crate named but broken would still be attempted, but the `|| log "Warning"` fallback covers that.
- **Follow-up**: Confirm no warning is emitted on a host without `cargo-cache`.

### Decision: docker builder prune emits its own progress event
- **Context**: The docker cleanup section has broad scope; builder prune is a distinct operation from `docker system prune`.
- **Selected Approach**: Emit `progress "Pruning Docker builder cache"` before `docker builder prune -f`, inside the existing `docker info` daemon guard.
- **Rationale**: Satisfies Req 6.1 (progress per cache-purge op) and keeps the builder prune gated on the running daemon (Req 3.3).
- **Trade-offs**: One extra progress line in the docker section; acceptable for observability.

## Risks & Mitigations
- Upstream restructuring of any target block invalidates an anchor — Mitigation: Revalidation Triggers section in design; re-verify placement before merge.
- `yarn cache clean` semantics differ between yarn v1 and Berry — Mitigation: command is backward-compatible; failure is non-fatal via `|| log`.
- `skip_rustup` is not checked by `command_exists cargo` — Mitigation: cargo autoclean inherits the cargo block's existing gating; Req 5.2's `skip_rustup` behavior follows whatever the surrounding block already does (no new logic added by this spec).

## References
- pip cache command — https://pip.pypa.io/en/stable/cli/pip_cache/ (available since pip 20.1)
- uv cache clean — https://docs.astral.sh/uv/reference/cli/#uv-cache-clean
- docker builder prune — https://docs.docker.com/reference/cli/docker/builder/prune/
- cargo-cache crate — https://crates.io/crates/cargo-cache
