# Implementation Plan

- [x] 1. Add pip and pip3 cache purge
- [x] 1.1 Add `pip cache purge` after the pip update block (P)
  - Locate the `if command_exists pip; then` block — find it by searching for the `export PIP_REQUIRE_VIRTUALENV=true` line that closes the pip update block
  - Insert immediately before the closing `fi`, after `export PIP_REQUIRE_VIRTUALENV=true`:
    ```bash
    progress "Purging pip cache"
    pip cache purge || log "Warning: pip cache purge failed"
    ```
  - Verify the line is inside the `command_exists pip` guard (so `skip_pip=1` suppresses it automatically)
  - Observable: `MOCK_MODE=1 ./htotheizzo.sh` output includes `PROGRESS:Purging pip cache`
  - _Requirements: 1.1, 1.2, 1.3, 6.1, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — pip block_

- [x] 1.2 Add `pip3 cache purge` after the pip3 update block (P)
  - Locate the `if command_exists pip3; then` block — find it by searching for the second `export PIP_REQUIRE_VIRTUALENV=true` (inside the pip3 update block, after `python3 -m pip install --upgrade pip`)
  - Insert immediately before the closing `fi`, after `export PIP_REQUIRE_VIRTUALENV=true`:
    ```bash
    progress "Purging pip3 cache"
    pip3 cache purge || log "Warning: pip3 cache purge failed"
    ```
  - Verify the line is inside the `command_exists pip3` guard
  - Observable: `MOCK_MODE=1 ./htotheizzo.sh` output includes `PROGRESS:Purging pip3 cache`
  - _Requirements: 1.4, 1.5, 1.6, 6.1, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — pip3 block_

- [x] 2. Add yarn cache clean
- [x] 2.1 Add `yarn cache clean` at the end of the yarn update block
  - Locate the `if command_exists yarn; then` block — find it by searching for `command_exists yarn` (the block contains Homebrew/corepack/npm yarn update branches)
  - Insert immediately before the closing `fi`, after all yarn update branches complete:
    ```bash
    progress "Cleaning yarn cache"
    yarn cache clean || log "Warning: yarn cache clean failed"
    ```
  - Verify the line is inside the `command_exists yarn` guard
  - Observable: `MOCK_MODE=1 ./htotheizzo.sh` output includes `PROGRESS:Cleaning yarn cache`
  - _Requirements: 4.1, 4.2, 4.3, 6.1, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — yarn block_

- [x] 3. Add uv cache clean
- [x] 3.1 Add `uv cache clean` at the end of the uv block
  - Locate the `if command_exists uv; then` block — find it by searching for `uv self update || log "Warning: uv self update failed"` (the block contains a Homebrew-skip branch and a standalone self-update branch)
  - Insert immediately before the closing `fi`, after both the Homebrew-skip branch and the `uv self update` branch:
    ```bash
    progress "Cleaning uv cache"
    uv cache clean || log "Warning: uv cache clean failed"
    ```
  - Verify the line is inside the `command_exists uv` guard and runs in both the Homebrew-managed and standalone paths
  - Observable: `MOCK_MODE=1 ./htotheizzo.sh` output includes `PROGRESS:Cleaning uv cache`
  - _Requirements: 2.1, 2.2, 2.3, 6.1, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — uv block_

- [x] 4. Add docker builder prune
- [x] 4.1 Add `docker builder prune -f` after `docker system prune` inside the daemon-running guard
  - Locate the `docker system prune -af --volumes || log "Warning: docker system prune failed"` line — find it by searching for that string inside the docker cleanup block (inside `if docker info &>/dev/null; then`)
  - Insert immediately after that line (still inside `if docker info &>/dev/null; then`):
    ```bash
    progress "Pruning Docker builder cache"
    docker builder prune -f || log "Warning: docker builder prune failed"
    ```
  - Verify this is inside the daemon-running guard and not in the podman branch
  - Observable: When Docker daemon is running and MOCK_MODE is not used, `docker builder prune -f` is called; with Docker not running the line is skipped. `PROGRESS:Pruning Docker builder cache` appears in MOCK_MODE output.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 6.1, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — docker block_

- [x] 5. Add cargo cache autoclean (soft check)
- [x] 5.1 Add soft-check cargo cache autoclean block inside the cargo section
  - Locate the `if command_exists cargo; then` block — find it by searching for `cargo install --list | grep -q "cargo-update"` (the existing cargo-update guard in the same block)
  - Insert at the end of the block, after the existing `cargo-update` logic:
    ```bash
    if cargo install --list | grep -q "cargo-cache"; then
      progress "Cleaning cargo cache"
      cargo cache --autoclean || log "Warning: cargo cache autoclean failed"
    fi
    ```
  - Verify: the inner `if` ensures no warning is emitted when `cargo-cache` is absent
  - Verify: the outer `command_exists cargo` guard means `skip_cargo=1` suppresses this
  - Observable: on a system with `cargo-cache` installed, `PROGRESS:Cleaning cargo cache` appears; on a system without it, nothing is printed
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.2, 6.3, 6.4_
  - _Boundary: htotheizzo.sh — cargo block_

- [x] 6. Verify pattern conformance and test pass
- [x] 6.1 Run test.sh and confirm all tests pass
  - Run `./test.sh` from the repo root
  - Observable: test.sh exits 0 with no failures reported
  - _Requirements: 6.5_
  - _Depends: 1.1, 1.2, 2.1, 3.1, 4.1, 5.1_

- [x] 6.2 Smoke-test with MOCK_MODE
  - Run `MOCK_MODE=1 ./htotheizzo.sh 2>&1 | grep PROGRESS`
  - Observable: New PROGRESS lines appear (`Purging pip cache`, `Purging pip3 cache`, `Cleaning uv cache`, `Cleaning yarn cache`, `Pruning Docker builder cache`) without any new errors
  - _Requirements: 6.1, 6.2, 6.3, 6.4_
  - _Depends: 1.1, 1.2, 2.1, 3.1, 4.1, 5.1_
