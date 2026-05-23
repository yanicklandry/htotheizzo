# Research Log: sudo-auth

## Discovery Scope
Minimal / Extension — two targeted edits to `htotheizzo.sh`. No external research required.

## Codebase Analysis

### keep_sudo_alive() (lines 72–77)
```bash
keep_sudo_alive() {
  ( while kill -0 $$ 2>/dev/null; do sudo -v 2>/dev/null; sleep 50; done ) &
  local keepalive_pid=$!
  disown "$keepalive_pid" 2>/dev/null || true
  trap "kill $keepalive_pid 2>/dev/null || true" EXIT INT TERM
}
```
- Current interval: 50 seconds
- macOS sudo TTL: ~300 seconds (5 minutes)
- Problem: 50s fires 6× per TTL window; each `sudo -v` with `pam_tid` triggers Touch ID sheet
- Fix: 240s → one refresh per window, ~60s safety margin

### softwareupdate block (lines 993–1010)
- `sw_list` captured via `softwareupdate --list 2>&1 | grep -v "^Software Update Tool" | grep -v "^Copyright"`
- No major-upgrade detection exists
- `skip_softwareupdate_major` already present as opt-out flag
- Comment at line 1000–1002 acknowledges the interactive password requirement

## Synthesis Outcomes

### Build vs Adopt
- No external libraries or tools. Detection logic is pure Bash using `sw_vers` (standard macOS CLI).

### Heuristic Design Decision
- Rejected: Matching on macOS release names (Sequoia, Tahoe, etc.) — brittle, breaks on new names
- Adopted: Integer major version comparison via `sw_vers -productVersion | cut -d. -f1` vs `Version: N` in sw_list output
- Rationale: Version integers are stable across Apple release naming conventions

### Simplifications Applied
- No new functions created — MajorUpgradeGuard is an inline shell block within the existing softwareupdate section
- No new skip flags added — existing `skip_softwareupdate_major` already handles the opt-out case

## Risks
- Apple changes `softwareupdate --list` output format: mitigated by fallback-to-no-warning behavior if "Version:" not found
- macOS sudo TTL changes: 240s is conservative; would need to revisit if TTL is reduced below 280s
