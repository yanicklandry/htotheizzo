# Implementation Plan

- [ ] 1. Remove backup_reminder function and call site
- [x] 1.1 (P) Delete backup_reminder function body (lines 236–281) from htotheizzo.sh
  - Remove the entire `backup_reminder()` block including all `tmutil` invocations and the `skip_backup_warning` guard.
  - Confirm no reference to `backup_reminder` or `skip_backup_warning` remains in the file after deletion.
  - _Requirements: 2.2, 2.4_
  - _Boundary: htotheizzo.sh pre-check section_

- [x] 1.2 (P) Delete backup_reminder call site (line 1037) from htotheizzo.sh
  - Remove the `backup_reminder` line from the pre-update health checks block.
  - Confirm `check_battery` is now the first call in that block.
  - _Requirements: 2.1, 2.3_
  - _Boundary: htotheizzo.sh pre-check section_
  - _Depends: 1.1_

- [ ] 2. Remove check_system_load function and call site
- [x] 2.1 (P) Delete check_system_load function body (lines 572–610) from htotheizzo.sh
  - Remove the entire `check_system_load()` block including the CPU temperature sysctl sub-block.
  - Confirm no reference to `check_system_load` or `skip_load_check` remains in the file.
  - _Requirements: 1.2, 1.4_
  - _Boundary: htotheizzo.sh pre-check section_

- [x] 2.2 (P) Delete check_system_load call site (line 1041) from htotheizzo.sh
  - Remove the `check_system_load` line from the pre-update health checks block.
  - Confirm `estimate_update_sizes` follows `check_network` with no missing calls in between.
  - _Requirements: 1.1, 1.3_
  - _Boundary: htotheizzo.sh pre-check section_
  - _Depends: 2.1_

- [x] 3. Remove replace_sysd dead code
- [x] 3.1 Delete replace_sysd function body (lines 711–717) from htotheizzo.sh
  - Remove the entire `replace_sysd()` block.
  - Confirm via grep that no call site for `replace_sysd` exists anywhere in the file.
  - _Requirements: 3.1, 3.2_
  - _Boundary: htotheizzo.sh function block_

- [x] 4. Deduplicate softwareupdate --list invocation
- [x] 4.1 Refactor the softwareupdate block (lines 1090–1105) to capture --list output in a variable
  - Capture the output of `softwareupdate --list 2>&1` into a local variable (e.g. `sw_list`) using `|| true` to prevent abort on non-zero exit.
  - Log the captured variable so the available-updates list is still visible in script output.
  - The install step (`--install --all` or `--install --recommended`) must not trigger a second `--list` call.
  - Confirm with grep that only one invocation of `softwareupdate --list` exists in the entire file after the change.
  - _Requirements: 4.1, 4.2_
  - _Boundary: htotheizzo.sh macOS update block_

- [x] 5. Reduce cache cleanup timeout and add find depth limit
- [x] 5.1 Update gtimeout branch: change 300 to 30 and add -maxdepth 3
  - In the `gtimeout` branch of the cache cleanup block, change `gtimeout 300` to `gtimeout 30`.
  - Add `-maxdepth 3` to the find invocation immediately before the `\(` name-pattern group.
  - Confirm the `|| log "Warning: cache cleanup timed out or failed"` fallback is preserved.
  - _Requirements: 5.1, 5.2, 6.1, 6.2_
  - _Boundary: htotheizzo.sh cache cleanup block_

- [x] 5.2 Update timeout branch: change 300 to 30 and add -maxdepth 3
  - In the `timeout` branch of the cache cleanup block, change `timeout 300` to `timeout 30`.
  - Add `-maxdepth 3` to the find invocation immediately before the `\(` name-pattern group.
  - Confirm the `|| log "Warning: cache cleanup timed out or failed"` fallback is preserved.
  - _Requirements: 5.1, 5.2, 6.1, 6.2_
  - _Boundary: htotheizzo.sh cache cleanup block_

- [x] 5.3 Update fallback branch: change elapsed ceiling from 300 to 30 and add -maxdepth 3
  - In the fallback (background process) branch, change the manual loop ceiling `$elapsed -lt 300` to `$elapsed -lt 30`.
  - Add `-maxdepth 3` to the find invocation in the same branch before the `\(` name-pattern group.
  - Confirm the `kill $find_pid` guard and warning log are preserved.
  - _Requirements: 5.1, 5.2, 6.1, 6.2_
  - _Boundary: htotheizzo.sh cache cleanup block_

- [x] 6. Remove stray sudo -v calls
- [x] 6.1 (P) Delete the sudo -v line near line 1168
  - Remove the line `sudo -v  # Refresh sudo credentials` that follows the OS branch block.
  - Confirm `update_itself` (or equivalent) is the next executable statement in sequence.
  - _Requirements: 7.1, 7.3_
  - _Boundary: htotheizzo.sh update function_

- [x] 6.2 (P) Delete the sudo -v line near line 1643
  - Remove the line `sudo -v  # Refresh sudo credentials` that precedes the gem update block.
  - Confirm `progress "Updating Ruby gems"` (or the gem update guard) is the next executable statement.
  - _Requirements: 7.2, 7.3_
  - _Boundary: htotheizzo.sh update function_

- [ ] 7. Validate changes with test suite
- [ ] 7.1 Run test.sh and confirm exit code 0
  - Execute `./test.sh` from the repo root.
  - All tests pass; exit code is 0.
  - If any test fails, identify the regression introduced by tasks 1–6 and fix it before marking this task complete.
  - _Requirements: 8.1, 8.2_
  - _Depends: 1.2, 2.2, 3.1, 4.1, 5.3, 6.2_

- [ ] 7.2 Static verification: confirm no deleted symbols remain
  - Run grep for `backup_reminder`, `check_system_load`, `replace_sysd`, `skip_load_check`, `skip_backup_warning` — all return no matches.
  - Run grep for `softwareupdate --list` — returns exactly one match.
  - Run grep for standalone `sudo -v` near the two deleted positions — returns no matches.
  - _Requirements: 1.2, 1.4, 2.2, 2.4, 3.1, 4.1, 7.1, 7.2_
  - _Depends: 1.2, 2.2, 3.1, 4.1, 5.3, 6.2_
