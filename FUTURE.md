# FUTURE.md — Ideas for future improvements

Collected from memory backlog, CLAUDE.md, and current codebase review.

---

## Known Bugs

- **Progress bar shows wrong operation** (`gui/renderer.js` `simulateProgress()`): grabs the last line of a stream chunk, but chunk boundaries don't align with operations. Label is often stale/wrong. Fix: emit structured progress events from the shell script (e.g. `PROGRESS: <step>`) and parse those explicitly.
- **GUI design is generic**: purple gradient + white card aesthetic. Could use native macOS vibrancy and a neutral palette to look at home on macOS 15+.
- **Better error context in GUI**: when errors appear in the error summary, there is no shortcut to the log file. Add a "Show Log" button that opens `~/logs/htotheizzo.log` in Console.app or the default text editor.
- **Multiple sudo/password prompts** (reported, partially fixed): `softwareupdate` was running without `sudo`, triggering a fresh authentication dialog mid-run. Fixed in this session. Also replaced `sudo echo "Kept sudo."` (ineffective keepalive) with `sudo -v`.

---

## Enhancements

### sudo keepalive — background refresh
Run `sudo -v` in a background loop for the duration of the script instead of two one-shot `sudo -v` calls. Prevents any command late in a long run from prompting again:
```bash
keep_sudo_alive() {
  while kill -0 $$ 2>/dev/null; do sudo -v; sleep 50; done &
}
```
Call once at the start of `update()`, before any package manager runs.

### `softwareupdate --list` preview
Before `sudo softwareupdate --install --all`, run `softwareupdate --list` and log what will be installed. Helpful for understanding what the "Password:" prompt was for.

### `brew autoremove`
Homebrew 3.x+ supports `brew autoremove` to uninstall unused dependencies. Add after `brew cleanup -s`.

### `brew bundle check` / `brew bundle install`
If a `Brewfile` exists in `$HOME` or `$DOTFILES`, run `brew bundle install` to reconcile installed packages against the declared state.

### Battery check before updates (macOS)
Warn if on battery power below 20% before kicking off long-running updates:
```bash
pmset -g batt | grep -q "Battery Power" && awk '/[0-9]+%/{print $1}' ...
```

### SSD health check
Add an optional `smartctl -H /dev/disk0` check (requires `smartmontools` from Homebrew) to the pre-update health section.

### npm — use `npm-check-updates` for global packages
`npm-check-updates -g` is more reliable than the current `npm outdated -g --json | jq ...` approach and works without `jq`.

### `omz update --unattended`
Replace bare `omz update` with `omz update --unattended` to prevent interactive prompts blocking the script.

### `mise upgrade` for tool versions
`mise upgrade` (in addition to `mise self-update`) updates all installed tool versions (e.g. Node, Python) to their latest allowed versions. Currently the script only updates the mise binary itself.

### `volta` and `fnm` support
Two popular Node version managers not yet handled:
- `volta fetch node@latest && volta install node@latest`
- `fnm install --lts`

### `bun pm global update` for global Bun packages
The script runs `bun upgrade` (updates Bun itself) but does not update globally installed Bun packages. Add `bun pm global update` after the Bun self-update.

### `topgrade` integration
[topgrade](https://github.com/topgrade-rs/topgrade) is a Rust-based meta-updater that already handles most of what htotheizzo does. Consider either adopting it as an optional backend or using it as a reference for missing updaters.

### Winget improvements (Windows `update.sh`)
Use `--accept-package-agreements --accept-source-agreements --silent` flags:
```bash
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements
```

### `snap refresh --list` preview (Linux)
Log available snap updates before running `snap refresh`, for visibility.

### `tldr --update` (tealdeer)
If `tldr` (tealdeer) is installed, run `tldr --update` to refresh the offline page cache.

### `rustup check` before update
`rustup check` reports what would change without modifying anything. Useful as a dry-run preview.

---

## GUI Improvements

- **Native macOS look**: Use Electron's `vibrancy` + `titleBarStyle: 'hiddenInset'` for a window that blends with macOS Ventura/Sonoma/Tahoe.
- **Show Log button**: Surface the log file path in the error summary section, with a one-click "Open in Console" action.
- **Package presets**: "Minimal" (brew + mas only), "Full" (everything), "Python" (pip/pyenv/poetry/uv), etc. — quick presets instead of checking boxes one by one.
- **Structured progress events**: Emit `PROGRESS:<label>` lines from htotheizzo.sh; parse them in renderer.js to replace the unreliable `simulateProgress()`.
- **Dock icon badge**: Show a red badge on the .app Dock icon when errors occurred (via `app.dock.setBadge()`).

---

## Maintenance

- Add `skip_self_update=1` to cron entries (self-update during a cron run can be disruptive if there's a merge conflict).
- Consider a `--dry-run` mode that actually skips all commands (not just `maybe_run()` calls which are currently unused). Make MOCK_MODE honour a `skip_<cmd>` pattern for every package manager block.
- Add shellcheck CI (GitHub Actions) to catch shell scripting bugs automatically.
