# Brief: sudo-auth

## Problem
Users running htotheizzo.sh on macOS with Touch ID for sudo get prompted 3+ times for fingerprint/password during a single run. The `keep_sudo_alive()` function calls `sudo -v` every 50 seconds, but macOS's sudo timestamp is 5 minutes — each `sudo -v` call triggers a Touch ID PAM sheet even when credentials are still valid. Additionally, `sudo softwareupdate --install --all` silently downloads major OS upgrades (e.g. macOS Tahoe) and then prompts for an interactive password that bypasses sudo credential caching — surprising the user with no prior warning.

## Current State

- `keep_sudo_alive()` sleeps 50s between `sudo -v` calls — fires ~6× per 5-min sudo timeout window
- Each `sudo -v` on macOS with `pam_tid` shows a Touch ID sheet even when credentials are valid
- `sudo softwareupdate --install --all` runs without inspecting whether updates include a major OS upgrade
- `skip_softwareupdate_major=1` exists as an escape hatch but is undiscoverable (no runtime warning)
- GitHub issue: yanicklandry/htotheizzo#14

## Desired Outcome

- Touch ID prompts at most once at script start, plus once if credentials genuinely expire (>5 min) mid-run
- Before installing a major OS upgrade, print a clear warning that an interactive password will be required, and remind the user they can set `skip_softwareupdate_major=1` to skip it
- No behavioral change for non-macOS platforms or when `pam_tid` is not in use

## Approach

Two targeted fixes in `htotheizzo.sh`:

1. **Keepalive interval**: Change `sleep 50` to `sleep 240` in `keep_sudo_alive()`. Credentials expire after 300s; sleeping 240s refreshes them with ~60s margin, keeping exactly one Touch ID prompt per 5-min window at most.

2. **Major upgrade warning**: After capturing `sw_list`, inspect it for lines that indicate a major OS upgrade (version number differs from current `sw_vers -productVersion` major). If found, print a prominent warning with `log` before running `--install --all`, telling the user an interactive password will be required and how to opt out.

## Scope
- **In**: `htotheizzo.sh` — `keep_sudo_alive()` function, `softwareupdate` block
- **Out**: changing the sudo PAM configuration, removing `keep_sudo_alive` entirely, fixing Linux/Windows paths, modifying the initial `sudo -v` auth gate

## Boundary Candidates
- Keepalive timing fix (pure interval change, no logic change)
- Major upgrade detection and warning (sw_list parsing + log output)

## Out of Boundary
- This spec does not change how many `sudo` calls other parts of the script make
- This spec does not suppress the macOS password prompt for major upgrades (Apple enforces it)
- This spec does not add skip flags for individual sudo operations

## Upstream / Downstream
- **Upstream**: `keep_sudo_alive()` at line 72; softwareupdate block at line 993
- **Downstream**: none — this is a standalone UX fix

## Existing Spec Touchpoints
- **Extends**: none
- **Adjacent**: script-cleanup touched the sudo area (removed two stray `sudo -v` calls)

## Constraints
- Must not break Linux path (keepalive is used there too; 240s interval is safe on any platform)
- Must not remove the initial `sudo -v` auth gate
- Major upgrade detection must be resilient to `softwareupdate --list` output format changes (use a loose heuristic, not a rigid parser)
- Must pass `./test.sh`
