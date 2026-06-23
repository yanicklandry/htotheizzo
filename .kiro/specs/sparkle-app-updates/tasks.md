# Implementation Plan

- [ ] 1. Foundation: test infrastructure and shared fixtures
- [x] 1.1 Add `skip_sparkle=1` to `run_htotheizzo_fast` in `test.sh`
  - Add `skip_sparkle=1` to the environment block of `run_htotheizzo_fast()` alongside the other `skip_*` vars so no existing fast-mode test ever scans `/Applications`.
  - Running the existing test suite (`./test.sh`) completes without touching `/Applications` and all previously passing tests still pass.
  - _Requirements: 4.1, 4.2, 6.1_

- [x] 1.2 Create a reusable test fixture factory for Sparkle-app tests
  - Add a `make_sparkle_fixture` helper in `test.sh` (or inline per test) that creates a temp directory, writes a minimal `.app/Contents/Info.plist` with a configurable `SUFeedURL` value, and places a configurable stub `update-app.sh` script (defaults to exit 0, records its args to a sentinel file, and can be overridden to exit non-zero).
  - The factory is called by subsequent `test_sparkle_*` functions; each test sets its own `ANTARES_DIR` and `SPARKLE_APP_DIRS` to the temp paths so no test touches the real `/Applications` or the real antares install.
  - Fixture teardown happens in the existing `cleanup()` function or via a `trap` in each test.
  - _Requirements: 1.1, 1.2, 6.3_

- [ ] 2. Core: implement `update_sparkle_apps()` in `htotheizzo.sh`
- [x] 2.1 Implement function entry: progress label and antares resolution
  - Define `update_sparkle_apps()` near the other `mac_*` helpers (after `mac_disk_maintenance()`).
  - First two statements emit `progress "Updating Sparkle apps"` and `log "Updating Sparkle apps..."` unconditionally — before any guard — so the section is always visible in the GUI and run log.
  - Resolve the updater path: `local updater="${ANTARES_DIR:-$HOME/Developer/2026/antares}/bin/update-app.sh"`.
  - If `[[ ! -x "$updater" ]]`: emit an informational `log` (not `log "Warning:"`) and `return 0` — the run continues cleanly and no warning appears in the end-of-run summary.
  - `progress "Updating Sparkle apps"` appears in output before any early return; `./test.sh` with a missing antares exits 0 and shows the skip message.
  - _Requirements: 3.1, 3.2, 3.3, 5.3, 6.4_

- [x] 2.2 Implement Sparkle app discovery loop
  - Split `SPARKLE_APP_DIRS` (default `/Applications`) on `:` using `IFS=:` to support colon-separated roots and paths with spaces.
  - For each root, glob `"$root"/*.app` using `shopt -s nullglob` (scoped, restored after) or equivalent guard so an empty root directory does not produce a literal-glob string under `set -euo pipefail`.
  - For each `.app` bundle: run `defaults read "$app/Contents/Info" SUFeedURL 2>/dev/null` using `|| continue` so an absent key is a silent skip (not an error and not a warning).
  - Filter out any feed value that does not start with `http`; such bundles are silently skipped.
  - Maintain a `local found=0` counter; increment it for each in-scope app.
  - Running `./test.sh` with a fixture dir containing one app with a valid feed and one without a feed confirms only the valid app reaches the delegation step.
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2.3 Implement per-app delegation with mock-mode gate, running-app skip, and failure handling
  - For each in-scope app: if `skip_sparkle_running` is set and `osascript -e 'application "'"$app_name"'" is running' 2>/dev/null` returns `true`, emit `log "Skipping running app: $app_name"` and `continue`.
  - If `[[ -n "$MOCK_MODE" ]]`: emit `log "[MOCK] Would update Sparkle app: $app_name"` and `continue` — the stub `update-app.sh` must never be executed in mock mode.
  - Otherwise invoke `"$updater" "$app"` (absolute bundle path, robust to spaces); on non-zero exit: `log "Warning: Sparkle update failed for $app_name"` and `continue` — the loop keeps going and the warning is captured into `ERROR_LOG` for the end-of-run summary.
  - Running `./test.sh` with a stub that exits non-zero shows the warning in output and the run exits 0; mock mode test shows `[MOCK]` lines and confirms the stub sentinel file is absent.
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 5.1, 5.2, 5.4, 6.2, 6.3_

- [x] 2.4 Implement "no apps found" path and function close
  - After the discovery loop completes, check `[[ $found -eq 0 ]]`; if true emit `log "No Sparkle apps found in ${SPARKLE_APP_DIRS:-/Applications}."`.
  - The function ends without an explicit return (returns 0 by reaching the end).
  - Running `./test.sh` with an empty `SPARKLE_APP_DIRS` temp dir produces the "No Sparkle apps found" log line and exits 0.
  - _Requirements: 1.4_

- [ ] 3. Integration: wire call site and update documentation
- [x] 3.1 Add the `skip_sparkle` call-site guard in the macOS branch of `update()`
  - Inside the `[[ "$OSTYPE" == "darwin"* ]]` branch of `update()`, after the `mas upgrade` and Microsoft AutoUpdate block (~line 1070), add the explicit skip guard:
    ```
    if [[ -z "${skip_sparkle:-}" ]]; then
      update_sparkle_apps
    else
      log "Skipped sparkle"
    fi
    ```
  - This mirrors the `disk_maintenance` / `spotlight` / `launchpad` pattern exactly.
  - Running `skip_sparkle=1 MOCK_MODE=1 ./htotheizzo.sh 2>&1 | grep "Skipped sparkle"` prints the skip line; running without the flag in MOCK mode shows the `progress "Updating Sparkle apps"` line.
  - _Requirements: 4.1, 4.2, 4.3, 6.1_

- [ ] 3.2 Update `help()` output and `CLAUDE.md` skip-commands documentation
  - Add `skip_sparkle=1` to the env-var examples in `help()` in `htotheizzo.sh`.
  - Add entries to the skip-commands table in `CLAUDE.md` for `skip_sparkle`, `skip_sparkle_running`, `ANTARES_DIR`, and `SPARKLE_APP_DIRS` (colon-separated).
  - Running `./htotheizzo.sh --help` shows `skip_sparkle` in the output; the `CLAUDE.md` table lists all four new env vars with descriptions.
  - _Requirements: 4.3_

- [ ] 4. Validation: integration tests and regression
- [ ] 4.1 Test: skip flag bypasses the entire section
  - Run htotheizzo with `skip_sparkle=1` and grep output for `Skipped sparkle`.
  - Assert the stub `update-app.sh` sentinel file is absent (updater was never invoked).
  - _Requirements: 4.1, 4.2_

- [ ] 4.2 Test: missing antares exits cleanly without warning
  - Point `ANTARES_DIR` at an empty temp dir; run htotheizzo without `skip_sparkle`.
  - Assert output contains the informational antares-not-found message and does NOT contain `Warning:`.
  - Assert overall run exits 0.
  - _Requirements: 3.3_

- [ ] 4.3 Test: mock mode never invokes the updater
  - Use the fixture from Task 1.2 (one app with a valid `http` feed, stub `update-app.sh` that writes a sentinel).
  - Run htotheizzo with `MOCK_MODE=1`.
  - Assert output contains `[MOCK] Would update Sparkle app:` and the sentinel file does not exist.
  - _Requirements: 6.3_

- [ ] 4.4 Test: valid-feed apps are delegated; non-http feed apps are skipped
  - Fixture contains two apps: one with `https://example.com/appcast.xml` feed, one with `file:///local` feed.
  - Run without mock mode; stub records invocation args.
  - Assert stub was called exactly once with the absolute path of the valid-feed app; the non-http app does not appear in args.
  - _Requirements: 1.1, 1.2, 2.1_

- [ ] 4.5 Test: empty app dirs produces "no apps found" log
  - `SPARKLE_APP_DIRS` points at an empty temp dir.
  - Assert output contains "No Sparkle apps found" and run exits 0.
  - _Requirements: 1.4_

- [ ] 4.6 Test: per-app failure is warned and run continues
  - Stub `update-app.sh` exits non-zero for the fixture app.
  - Assert output contains `Warning: Sparkle update failed`.
  - Assert run exits 0.
  - Assert the end-of-run summary contains the warning count (matches `updates completed with.*warning` pattern already used by `test_error_tracking`).
  - _Requirements: 5.1, 5.2, 5.4_

- [ ] 4.7 Regression: existing fast-path tests still pass
  - Run the full `./test.sh` suite.
  - Assert `test_skip_flags`, `test_mock_mode`, `test_health_checks`, and `test_error_tracking` all show `[PASS]` and no `/Applications` scan occurs during the run.
  - _Requirements: 4.1, 6.1_
