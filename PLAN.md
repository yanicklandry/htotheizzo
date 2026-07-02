# htotheizzo: Plan

_Last updated: 2026-06-25_

htotheizzo has two independent layers. The **shell script** (`htotheizzo.sh`) is stable and handles 60+ package managers — it needs targeted bug fixes and a few missing commands. The **GUI** (`gui/`, Electron) works but feels generic, uses 200-400 MB RAM, and has UI bugs around progress display and error surfacing. With AI-assisted development mature in 2026, a native GUI rewrite is now practical and worth evaluating.

This document tracks all known bugs (with solutions), planned enhancements, the GUI platform decision, and a ready-to-create GitHub issues list.

---

## Bugs

### Script Bugs

#### `brew upgrade` failure shows only one line

**Observed:**
```
[2026-06-22 21:42:27] Warning: brew upgrade failed
```
No list of which packages failed, no log path to inspect.

**Solution:** Capture stderr to a temp file and log per-package errors:
```bash
brew_log=$(mktemp)
brew upgrade --cask --greedy 2>"$brew_log" || {
  log "Warning: brew upgrade failed. Packages with errors:"
  grep -E "^Error:" "$brew_log" | head -20 | while read -r line; do log "  $line"; done
  log "Full log: $brew_log"
}
```

---

#### `brew cleanup` permission error has no actionable fix

**Observed:**
```
[2026-06-22 21:42:24] Updating Homebrew with casks...
[2026-06-22 21:42:27] Warning: brew upgrade failed
Removing: /opt/homebrew/Cellar/python@3.13/3.13.13_1... (2,727 files, 50.4MB)
Warning: Permission denied @ apply2files - .../utf_8_sig.cpython-313.pyc
Error: Could not cleanup old kegs! Fix your permissions on:
  /opt/homebrew/Cellar/python@3.13/3.13.13_1
[2026-06-22 21:42:38] Warning: brew cleanup failed
```

**Analysis:** Two separate failures. `brew upgrade` failed first (unrelated to cleanup). `brew cleanup` then failed on leftover files with wrong ownership — Python `.pyc` files in `/opt/homebrew/Cellar` sometimes have wrong ownership after a run as root or a Python version upgrade.

**Solution:** Detect the specific error message and print an actionable one-liner fix:
```bash
brew cleanup -s 2>&1 | tee "$cleanup_log" || {
  if grep -q "Could not cleanup old kegs" "$cleanup_log"; then
    log "Warning: brew cleanup failed: permission issue on old keg."
    log "Fix: sudo chown -R \$(whoami) \$(brew --prefix)/Cellar"
    log "Then re-run htotheizzo or: brew cleanup -s"
  else
    log "Warning: brew cleanup failed. See $cleanup_log"
  fi
}
```

---

#### Sparkle: tries to update already-up-to-date apps

**Observed:**
```
[2026-06-22 21:43:06] Updating Sparkle apps...
AppCleaner: installed 3.6.8 => latest stable 3.6.8
  download: https://rawcdn.githack.com/.../AppCleaner_3.6.8.zip
✓ already up to date (installed 3.6.8 >= stable 3.6.8).
```
The download URL is printed even though the app is current, meaning the download path runs before the version guard.

**Solution:** Move the version comparison before any download attempt:
```bash
if version_gte "$installed_version" "$latest_version"; then
  log "  ✓ $app_name already up to date ($installed_version)"
  continue
fi
```

---

#### Sparkle: `PROGRESS:` line format inconsistent

**Observed:** `PROGRESS:Updating Sparkle apps` (no space after colon, different from the rest of the script).

**Solution:** Fix the log statement. The GUI parser expects `PROGRESS:<label>` with no space — confirm one consistent format is used throughout the script and document it in tech.md.

---

#### Sparkle: update failure shows no error detail

**Observed:**
```
[2026-06-22 21:43:07] Warning: Sparkle update failed for cmux
```
No indication of what went wrong.

**Solution:** Capture stderr and inline the first meaningful line:
```bash
sparkle_err=$(mktemp)
update_sparkle_app "$app" 2>"$sparkle_err" || {
  first_err=$(grep -v "^$" "$sparkle_err" | head -1)
  if [ -n "$first_err" ]; then
    log "Warning: Sparkle update failed for $app: $first_err"
  else
    log "Warning: Sparkle update failed for $app (no stderr). Log: $sparkle_err"
  fi
}
```

---

#### Sparkle: depends on external Antares repo

The Sparkle updater calls `$ANTARES_DIR/bin/update-app.sh`. When Antares is absent the skip is silent — no message tells the user why Sparkle was skipped.

**Options (pick one):**
- **Inline it** (recommended): copy the relevant shell functions from Antares into `htotheizzo.sh` directly, removing the external dependency entirely.
- **Git submodule**: add Antares at `vendor/antares`; requires `git submodule update --init` on first run.
- **At minimum:** log a clear message when `ANTARES_DIR` is missing so the user knows why Sparkle was skipped.

---

### GUI Bugs

#### Progress bar shows wrong operation

`simulateProgress()` in `gui/renderer.js` grabs the last line of a stream chunk. Chunk boundaries do not align with operations, so the label is often stale.

**Solution:** The script already emits `PROGRESS:<label>` lines. The GUI just needs to detect the prefix and update the label directly — no simulation needed. Remove `simulateProgress()` entirely.

---

#### No path to the log file when errors occur

The error summary panel shows which operations failed but gives no way to inspect the full output.

**Solution:** Add a "Show Log" button that opens `~/logs/htotheizzo.log` in Console.app or the default text editor.
- Electron: `shell.openPath(logPath)`
- SwiftUI: `NSWorkspace.shared.open(logURL)`

---

## Enhancements

### Script — High Priority

**`keep_sudo_alive()` background loop**
Run `sudo -v` in a background loop for the duration of the script instead of two one-shot calls. Prevents any command late in a long run from prompting for a password again:
```bash
keep_sudo_alive() {
  while kill -0 $$ 2>/dev/null; do sudo -v; sleep 50; done &
}
```
Call once at the start of `update()`, before any package manager block runs.

---

### Script — Medium Priority

**`softwareupdate --list` preview**
Before `sudo softwareupdate --install --all`, run `softwareupdate --list` and log what will be installed. Makes clear what the password prompt was for.

**`brew autoremove`**
Homebrew 3.x+ supports `brew autoremove` to uninstall unused dependencies. Add after `brew cleanup -s`.

**`brew bundle check` / `brew bundle install`**
If a `Brewfile` exists in `$HOME` or `$DOTFILES`, run `brew bundle install` to reconcile installed packages against declared state.

**`mise upgrade` for tool versions**
`mise upgrade` updates installed tool versions (Node, Python, etc.) to their latest allowed version. The script currently only updates the mise binary itself with `mise self-update`.

**Shellcheck CI via GitHub Actions**
Add a workflow that runs `shellcheck htotheizzo.sh` on every push. Catches shell scripting bugs before they reach users.

---

### Script — Low Priority

**`volta` and `fnm` support**
Two popular Node version managers not yet handled:
- `volta fetch node@latest && volta install node@latest`
- `fnm install --lts`

**`bun pm global update`**
The script runs `bun upgrade` (updates Bun itself) but does not update globally installed Bun packages. Add `bun pm global update` after the self-update.

**`topgrade` integration**
[topgrade](https://github.com/topgrade-rs/topgrade) is a Rust meta-updater that covers most of what htotheizzo does. Consider adopting it as an optional backend or mining it for missing updater commands.

**`omz update --unattended`**
Replace bare `omz update` with `omz update --unattended` to prevent interactive prompts blocking the script.

**`npm-check-updates -g`**
More reliable than the current `npm outdated -g --json | jq ...` approach and works without `jq`.

**`tldr --update` (tealdeer)**
If `tldr` is installed, run `tldr --update` to refresh the offline page cache.

**`rustup check` before update**
`rustup check` reports what would change without modifying anything — useful as a dry-run preview before `rustup update`.

**`snap refresh --list` preview (Linux)**
Log available snap updates before running `snap refresh`, for visibility.

**Winget improvements (Windows)**
Add `--accept-package-agreements --accept-source-agreements --silent` flags:
```bash
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
```

**Battery check before updates (macOS)**
Warn if on battery power below 20% before kicking off long-running updates.

**SSD health check**
Add an optional `smartctl -H /dev/disk0` check (requires `smartmontools` from Homebrew).

**`--dry-run` mode**
A mode that skips all commands (not just `maybe_run()` calls). Make `MOCK_MODE` honour a `skip_<cmd>` pattern for every package manager block.

---

### GUI Enhancements

**Package presets**
"Minimal" (brew + mas only), "Full" (everything), "Python" (pip/pyenv/poetry/uv), "Node" (nvm/fnm/volta/npm) — quick preset buttons instead of checking boxes one by one.

**Dock icon badge**
Show a red badge on the `.app` Dock icon when the run completes with errors.
- Electron: `app.dock.setBadge(String(errorCount))`
- SwiftUI: `NSDockTile.default.badgeLabel = "\(errorCount)"` (1 line)

---

### Maintenance

- Add `skip_self_update=1` to cron entries (self-update during a cron run is disruptive if there is a merge conflict).

---

## GUI Platform Decision

The current Electron GUI uses 200-400 MB RAM and 80-150 MB on disk. With AI-assisted development mature in 2026 (Claude integrated in Xcode, models trained on large SwiftUI corpora), native alternatives are now practical.

### Comparison

| Framework | RAM idle | Installer | PTY support | Touch ID | Dock badge | AI ease | Native feel |
|---|---|---|---|---|---|---|---|
| Electron (current) | 200-400 MB | 80-150 MB | node-pty | via shell | `app.dock.setBadge()` | High | Low |
| Tauri v2 | 30-50 MB | 5-10 MB | tauri-plugin-pty | via Rust | via AppKit bridge | High | Medium-High |
| SwiftUI | 30-50 MB | 5-20 MB | POSIX + AsyncStream | 2 lines | 1 line | Very High | Very High |
| Flutter macOS | 50-80 MB | 15-30 MB | platform channels | via plugin | via plugin | Medium | Medium |

### Option A: Improve Electron (no rewrite)

Fix the known GUI bugs, add vibrancy and `hiddenInset` title bar, Show Log button, and Dock badge. Keep Electron and Node.js.

**Pros:** No rewrite, no new languages, fastest path to fixing current bugs.
**Cons:** 200-400 MB RAM, vibrancy via Electron is limited and flaky, Touch ID requires shell-out workarounds, technical debt accumulates as Electron major versions break regularly.
**Effort:** Small (1-2 days).

### Option B: Migrate to Tauri v2

Replace Electron with Tauri v2 (WebKit + Rust backend). Keep the existing HTML/CSS/JS frontend almost entirely. Replace `node-pty` with `tauri-plugin-pty` (stable since August 2025).

Migration steps:
1. `npm create tauri-app` to scaffold the new wrapper
2. Port `index.html` and `renderer.js` as-is (minor API call changes)
3. Replace `main.js` IPC with Tauri commands in Rust
4. Use `tauri-plugin-pty` for PTY streaming
5. Expose Touch ID (`LocalAuthentication`) and Dock badge (`NSDockTile`) from Rust

**Pros:** Keep HTML/CSS/JS skills, 10x smaller installer and memory footprint, PTY solved by a library, native macOS features accessible via Rust bridge.
**Cons:** Rust backend is new (AI handles boilerplate well), some Electron APIs need porting, WebView UI is still not 100% native-looking.
**Effort:** Medium (3-5 days).

### Option C: Rewrite in SwiftUI

Replace the Electron GUI entirely with a native SwiftUI macOS app. The shell script stays unchanged.

Implementation:
1. SwiftUI `ContentView`: category checkboxes, scrollable output log, Run button, error summary
2. PTY via POSIX `openpty()` + `Foundation.Process` + `DispatchIO` (~80-100 lines, well-documented SwiftTerm pattern)
3. ANSI stripping via `NSRegularExpression` (one regex)
4. Touch ID: `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` (2 lines)
5. Dock badge: `NSDockTile.default.badgeLabel = "\(errorCount)"` (1 line)
6. Show Log: `NSWorkspace.shared.open(logURL)` (1 line)

**Pros:** Best macOS integration possible, 30-50 MB RAM, all native features in 1-2 lines each, no Chromium or Node, Claude writes SwiftUI correctly at high quality in 2026.
**Cons:** Full rewrite (JS frontend cannot be reused), Swift is a new language (AI handles patterns well but debugging edge cases requires reading Swift), Xcode required.
**Effort:** Medium-Large (5-7 days, lower with AI assistance).

### Recommendation

**Short term:** Fix the script bugs listed above — they are independent of the GUI platform decision.

**GUI platform:**
- Pick **Tauri v2** if you want to keep the HTML/JS frontend and stay in the web stack. The migration is mechanical and the PTY problem is solved by a library. Lower risk.
- Pick **SwiftUI** if you want the best long-term macOS integration. PTY boilerplate is a one-time ~100-line implementation. The end result is a genuinely native macOS app. AI productivity on SwiftUI is at its peak in 2026.
- **Avoid Electron long-term** for a macOS-only tool — memory and feel both improve dramatically with either native option.

---

## GitHub Issues Plan

Review this list and create issues manually when ready.

### Bugs: Script

| # | Title | Labels | Priority |
|---|---|---|---|
| 1 | `brew upgrade` failure: show per-package errors and log path | `bug` `script` | High |
| 2 | `brew cleanup` permission error: detect and print `sudo chown` fix command | `bug` `script` | High |
| 3 | Sparkle: skip already-up-to-date apps before attempting download | `bug` `sparkle` | Medium |
| 4 | Sparkle: `PROGRESS:` line format inconsistent with rest of script | `bug` `sparkle` | Low |
| 5 | Sparkle: update failure shows no error detail — capture and log first stderr line | `bug` `sparkle` | Medium |
| 6 | Sparkle: remove or vendor Antares dependency; log clear message when absent | `bug` `sparkle` `dependencies` | Medium |

### Bugs: GUI

| # | Title | Labels | Priority |
|---|---|---|---|
| 7 | Fix progress label: parse `PROGRESS:` prefix instead of simulating | `bug` `gui` | High |
| 8 | Add "Show Log" button in error summary | `bug` `gui` | High |

### Enhancements: Script

| # | Title | Labels | Priority |
|---|---|---|---|
| 9 | Add `keep_sudo_alive()` background loop to prevent mid-run password prompts | `enhancement` `script` | High |
| 10 | Add `softwareupdate --list` preview before `--install --all` | `enhancement` `script` | Medium |
| 11 | Add `brew autoremove` after `brew cleanup -s` | `enhancement` `script` | Medium |
| 12 | Add `mise upgrade` for installed tool versions (not just the mise binary) | `enhancement` `script` | Medium |
| 13 | Add shellcheck CI via GitHub Actions | `enhancement` `ci` | Medium |
| 14 | Add `volta` and `fnm` Node version manager support | `enhancement` `script` | Low |
| 15 | Add `bun pm global update` for globally installed Bun packages | `enhancement` `script` | Low |
| 16 | Add `tldr --update` (tealdeer) if installed | `enhancement` `script` | Low |
| 17 | Replace `npm outdated -g --json \| jq` with `npm-check-updates -g` | `enhancement` `script` | Low |
| 18 | Replace bare `omz update` with `omz update --unattended` | `enhancement` `script` | Low |
| 19 | Add `--dry-run` mode respecting all `skip_*` env vars | `enhancement` `script` | Low |

### Enhancements: GUI

| # | Title | Labels | Priority |
|---|---|---|---|
| 20 | Show Dock icon badge with error count after run | `enhancement` `gui` | Medium |
| 21 | Add package presets: Minimal / Full / Python / Node | `enhancement` `gui` | Medium |

### GUI Platform

| # | Title | Labels | Priority |
|---|---|---|---|
| 22 | RFC: GUI platform decision — Tauri v2 vs SwiftUI vs Electron | `discussion` `gui` `rfc` | High |
| 23 | (after RFC) Migrate GUI to Tauri v2 | `enhancement` `gui` `tauri` | High |
| 24 | (after RFC) Rewrite GUI in SwiftUI | `enhancement` `gui` `swiftui` | High |

Create issue 22 first. Create 23 or 24 only after the RFC resolves the platform choice.
