# Implementation Plan

> All implementation lives in `htotheizzo.sh` and `test.sh`, so tasks are sequential (no `(P)`): parallel edits to the same script would conflict.

- [x] 1. Foundation: test harness, permitted-command list, rule text and probe
- [x] 1.1 Build the test harness for unattended and sudoers tests
  - Extend the existing function-extraction approach so tests can load the new sudoers constants, the permitted-command list and helper functions without running the script
  - Add a stub directory placed first on PATH with recording stubs for sudo (rejects the plain non-interactive credential check, accepts the probe only for a configured token, records every other call), the software update tool (prints a configured listing), the notification tool (succeeds so the notification is logged), the preferences reader (prints a configured value or fails) and the indexing tool
  - Add a non-mock unattended runner limited to the sections under test, with a temporary HOME, that aborts if the sudo found on PATH is not the stub
  - Done when: a smoke test proves the runner completes an unattended run that touches no real sudo (stub log shows every sudo call) and existing tests still pass
  - _Requirements: 3.3, 4.3_

- [x] 1.2 Define the permitted-command list and generate the rule text deterministically
  - Add the five permitted command lines from design.md (absolute system path plus exact arguments), the test-only rule-file path override, and the strict-mode-safe initial values for the rule-active flag and pending-update count
  - Generate the rule body (commands without arguments rendered with the empty-arguments marker), the probe token from a hash of user plus body, the full file text with a "generated, do not edit, how to remove" header, and a validation helper that runs the sudoers validator on a given file
  - Abort with an error when the current user name contains characters outside letters, digits, dot, underscore, hyphen
  - Tests: the generated text passes the validator as the unprivileged user; a deliberately broken temp file fails it; two generations are byte-identical; every entry satisfies the allowlist invariants (system path prefix, no wildcard/meta characters, no shell, sudo, su, xcodebuild, periodic or htotheizzo); the probe token changes when the list changes
  - Done when: these tests pass and printing the rule text shows one NOPASSWD line with the five commands plus the probe entry
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6_

- [x] 1.3 Add the "current rule active" probe
  - Check, without reading the root-only file and ignoring cached credentials, whether the probe entry for the current token runs without a password, never prompting and with stdin closed
  - Tests with the stub sudo: success only when the stub receives the ignore-cache and non-interactive options with the current token; failure for a stale token or a rejecting stub
  - Done when: these tests pass
  - _Requirements: 2.3, 2.4, 3.4_

- [x] 2. Setup: install, uninstall and status
- [x] 2.1 Implement the install-permission option
  - Wire `--install-sudoers` into flag parsing; refuse with a "macOS only" message and exit 1 on non-macOS
  - Validate the generated file before any privileged step; on failure print the validator output and exit 1 without touching the system
  - Refuse to install to any path other than the real rule location unless the test flag is set
  - Authenticate once interactively, back up an existing rule under a name sudo ignores, install the new file owned by root:wheel with mode 0440, validate the whole configuration, run the probe; on any failure restore the backup (or remove the file) and exit 1 naming the cause; on success remove the backup and print the permitted commands, the file location and how to remove it
  - Never store or read a password
  - Tests: non-macOS OS type exits 1 with the macOS-only message; when validation fails, the stub sudo records no install call
  - Done when: these tests pass (real install verified in 5.2)
  - _Depends: 1.2, 1.3_
  - _Requirements: 1.2, 1.3, 1.4, 1.7, 1.8, 1.9_

- [x] 2.2 Implement the uninstall-permission option and the status section
  - Wire `--uninstall-sudoers`: remove the rule if present and confirm; when absent, say nothing was installed and exit 0
  - Add a status section reporting active with the permitted-command count (probe entry not counted), installed but outdated with a hint to re-run install, or not installed
  - Tests using the rule-file override and the stub sudo: all three status states print the expected line; uninstall with no file exits 0 with the nothing-installed message
  - Done when: these tests pass
  - _Depends: 1.3_
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [x] 3. Unattended runtime behavior
- [x] 3.1 Switch macOS maintenance call sites to the exact permitted forms
  - Volume verification, memory purge, locate database update, DNS cache flush and mDNSResponder restart use the absolute paths and exact arguments in the permitted-command list
  - The locate database update runs directly (the periodic-scripts branch is removed); Xcode license acceptance keeps its current form (attended-only)
  - Done when: a test asserts each of these call sites matches a permitted entry exactly, and existing tests still pass
  - _Depends: 1.2_
  - _Requirements: 3.1, 4.1_

- [x] 3.2 Replace the unattended skip-everything shadow with the default-deny wrapper
  - At the start of an unattended run (when credentials are not already available), run the probe once using a set-e-safe form, remember the result and log either "sudo rule active (N commands permitted)" or the existing skip message
  - In unattended mode only: run a sudo call non-interactively with stdin closed when the rule is active and the call exactly matches a permitted entry; otherwise log it as skipped and count it, as today
  - In unattended mode, the Ruby gem block logs its sudo steps as skipped and counts them before reaching its command substitution, so the count is not lost
  - Leave attended, mock and sudo-skip modes untouched; permitted commands that fail still produce the caller's warning
  - Tests with the unattended runner: active rule plus permitted call reaches the stub with the non-interactive option; a non-permitted call is skipped and counted; inactive rule skips everything except the probe; a mock run never defines the wrapper
  - Done when: these tests pass
  - _Depends: 1.1, 1.3, 3.1_
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.6, 4.2, 4.3_

- [x] 3.3 Report instead of install macOS updates in unattended runs
  - After the existing update listing, in unattended mode count pending updates with a strict-mode-safe count, log the count and where to install them, and skip the major-upgrade detection, stored-password path and installation
  - The skip adds nothing to the error summary or the skipped-sudo count
  - Tests with the stub update tool: two listed updates yield no install call, a "2 pending" log line and an unchanged error summary; zero updates yield no pending line and exit 0 under strict mode
  - Done when: these tests pass
  - _Requirements: 5.1, 5.5_

- [x] 3.4 Make the Spotlight rebuild opt-in
  - Rebuild only when the explicit rebuild setting or only-spotlight mode is set and spotlight is not skipped
  - Tests with the stub sudo (mandatory, since this path bypasses mock protection): a default run records no indexing call; with the opt-in setting the stub records the indexing call
  - Done when: these tests pass
  - _Depends: 1.1_
  - _Requirements: 6.1, 6.2_

- [x] 4. Integration: reporting and user-facing text
- [x] 4.1 Extend the completion report and notification
  - Append the skipped admin-step count to the completion notification when non-zero, and "macOS updates pending" when updates were counted; leave both out otherwise
  - Update the "steps needing sudo were skipped" note to point to the install-permission option when the rule is not active, keeping the wording the status parser relies on
  - When updates are pending and the Automatic Updates install setting reads exactly off, log the System Settings tip; show nothing when the value is on, missing or unreadable (strict-mode-safe read)
  - Tests via the logged "Notification sent:" line: each suffix appears only in its scenario; the tip appears for a stubbed off value and not for on or a failing read
  - Done when: these tests pass and `--status` still parses the skipped count from logs
  - _Depends: 3.2, 3.3_
  - _Requirements: 3.5, 5.2, 5.3, 5.4_

- [x] 4.2 Update help text, README and steering
  - Help lists `--install-sudoers` and `--uninstall-sudoers` with one-line descriptions and documents the Spotlight opt-in setting
  - README gains an "Unattended sudo" section: the five permitted commands, why Xcode license and periodic are excluded, the security trade-off, how to remove, macOS updates left to Automatic Updates or attended runs
  - Steering tech.md states that new root steps for unattended runs must be added to the permitted list with exact arguments and must not execute user-controllable code, and records the Spotlight opt-in
  - Done when: `htotheizzo.sh --help` shows the new lines and the README and steering sections exist
  - _Requirements: 6.3, 7.1, 7.2, 7.3_

- [ ] 5. Validation
- [x] 5.1 Full regression and portability check
  - Run the complete test suite and a syntax check under macOS's bundled bash 3.2 and under bash 5
  - Done when: all tests pass under both and no bash-4-only constructs were introduced
  - _Requirements: 1.5, 3.3, 4.1, 4.3_

- [ ] 5.2 Real-machine verification (requires the user's one-time authentication)
  - Run the install option (one Touch ID or password); confirm `--status` shows active with 5 commands; confirm `/etc/sudoers.d/htotheizzo` is `-r--r-----` owned by root:wheel with no leftover backup
  - Trigger the launchd agent once and confirm the log shows the five permitted steps ran with no prompt and only non-permitted steps were skipped and counted
  - Run uninstall and confirm status shows not installed, then reinstall if the user wants to keep it
  - Done when: the user has confirmed each step's output (implementation pauses here for the user)
  - _Requirements: 1.4, 1.7, 1.9, 2.1, 2.3, 3.1, 3.3_
