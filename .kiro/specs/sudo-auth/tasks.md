# Implementation Plan

- [x] 1. Fix keepalive refresh interval
  - Locate `keep_sudo_alive()` in `htotheizzo.sh` (around line 73)
  - Change `sleep 50` to `sleep 240` — this is a single-constant change; no other lines in the function are touched
  - Run `bash -n htotheizzo.sh` to confirm no syntax errors were introduced
  - `keep_sudo_alive()` contains `sleep 240`; all surrounding function logic is unchanged
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Add major OS upgrade detection and warning
  - After `sw_list` is captured in the `softwareupdate` block (after the existing `while IFS= read -r line` log loop, before the `if [[ -z "${skip_softwareupdate_major:-}" ]]` branch), insert a detection block
  - Read the current macOS major version: `sw_vers -productVersion | cut -d. -f1` (e.g. "15")
  - Scan `sw_list` for lines matching `Version: N` (where N is an integer); extract the major integer from each matched line
  - If any extracted major integer differs from the current major, call `log` with a prominent multi-line warning that includes: (a) a `WARNING` or `⚠` indicator, (b) a statement that a major macOS upgrade is available and will require an interactive password that bypasses sudo credential caching, (c) a reminder that setting `skip_softwareupdate_major=1` will skip major upgrades and use `--recommended` instead
  - Place the detection block inside the outer `if [[ -z "${skip_softwareupdate:-}" ]]` guard; only run detection when `skip_softwareupdate_major` is unset (requirement 2.6: no warning when the flag suppresses the install anyway)
  - If `sw_vers` returns unexpected output or no "Version:" line is found in `sw_list`, fall back silently (no warning, no error) — safe default
  - Run `bash -n htotheizzo.sh` to confirm no syntax errors
  - When `sw_list` contains an update with a different major version, the warning is printed to the log before installation; when no major upgrade is present, or when `skip_softwareupdate_major=1` is set, no warning appears
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 3. Smoke test both changes
  - Verify `keep_sudo_alive()` contains `sleep 240` via grep: `grep -n 'sleep' htotheizzo.sh` shows `sleep 240` inside the keepalive loop and no other `sleep 50` remains there
  - Manually unit-test the upgrade detection by temporarily setting `sw_list` to a value containing `"Version: 26"` (simulated future major) while on macOS 15 and running the detection block in isolation — confirm the warning is emitted containing both "interactive password" and "skip_softwareupdate_major=1"
  - Manually test with `sw_list` containing only `"Version: 15"` — confirm no warning is emitted
  - Manually test with `skip_softwareupdate_major=1` set and a major-upgrade `sw_list` — confirm no warning is emitted and the `--recommended` branch is taken
  - Run `bash -n htotheizzo.sh` — script passes syntax check with zero errors
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
