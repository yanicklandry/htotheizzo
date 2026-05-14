# Research & Design Decisions

## Summary

- **Feature**: `script-cleanup`
- **Discovery Scope**: Simple subtraction (deletions + constant edits in one file)
- **Key Findings**:
  - All three functions to remove (`check_system_load`, `backup_reminder`, `replace_sysd`) have no callers outside `htotheizzo.sh` itself; `replace_sysd` has no caller at all.
  - The `softwareupdate --list` duplicate was confirmed by code inspection: lines 1091–1092 log the list, then the install path (lines 1099/1101) calls `softwareupdate --install` which does not implicitly re-run `--list`; the original code just ran `--list` twice unnecessarily before the fix was understood.
  - The 300 s timeout in the cache cleanup block is excessive; `~/Library/Caches` find operations on typical developer machines complete in under 10 s at depth 3.
  - The two stray `sudo -v` calls (lines 1168, 1643) are confirmed redundant: `keep_sudo_alive()` is started before `update()` and loops `sudo -v` every 60 s unconditionally.

## Research Log

### Function call-site audit
- **Context**: Verify that removing each function leaves no dangling references.
- **Findings**:
  - `backup_reminder`: defined line 236, called once at line 1037. No other references.
  - `check_system_load`: defined line 572, called once at line 1041. No other references.
  - `replace_sysd`: defined line 711, **no call sites found**.
  - `skip_backup_warning` and `skip_load_check`: referenced only inside their respective functions; safe to remove with the function.

### softwareupdate --list invocation count
- **Context**: Determine whether the install step triggers an implicit --list.
- **Findings**: `softwareupdate --install --all` and `--install --recommended` do not re-run `--list` internally. The duplicate was an explicit second invocation in the original code (now resolved by capturing into a variable).

### Cache cleanup timeout analysis
- **Context**: Validate that 30 s is a safe replacement for 300 s.
- **Findings**: The find pattern `\( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete` with `-maxdepth 3` on `~/Library/Caches` operates on a shallow, bounded set. 30 s is generous for this scope. The warning + continue pattern ensures a timeout is never fatal.

### sudo keepalive loop audit
- **Context**: Confirm keep_sudo_alive covers the full duration of the run.
- **Findings**: `keep_sudo_alive()` is invoked just before `update()` starts (confirmed in the call sequence). It runs in the background and loops every 60 s. The two stray `sudo -v` lines at 1168 and 1643 fall well within the keepalive window.

## Design Decisions

### Decision: Capture softwareupdate --list in a variable rather than piping to tee

- **Context**: The list output needed to be both logged and prevent a second call.
- **Alternatives Considered**:
  1. Run `--list` and pipe to `tee` to a temp file, then cat the file before install.
  2. Capture into a local variable with `$()`, log it, then proceed to install.
- **Selected Approach**: Local variable capture.
- **Rationale**: No temp file needed; no cleanup required; simpler and safe under `set -euo pipefail` with `|| true`.
- **Trade-offs**: Output is buffered until `--list` completes (not streamed line-by-line), which is acceptable for a list operation.

### Decision: Apply depth limit to all three code paths (gtimeout, timeout, fallback)

- **Context**: The three branches share the same find pattern; applying the change to only some would leave inconsistent behavior.
- **Selected Approach**: Update all three branches uniformly.
- **Rationale**: Consistency and correctness; an untouched fallback branch would still be able to scan unboundedly.

## Risks & Mitigations

- **Risk**: cache-cleanup spec later modifies the same find block and reverts the depth limit or timeout. — **Mitigation**: The cache-cleanup spec must read this design before modifying the cache section; a note in Boundary Commitments calls this out as a revalidation trigger.
- **Risk**: A future contributor re-adds a `sudo -v` line not knowing the keepalive loop is active. — **Mitigation**: The tech.md steering document already documents the "Do not add additional `sudo -v` calls" rule; this change reinforces that.
