# Research & Design Decisions

## Summary
- **Feature**: `unattended-sudo`
- **Discovery Scope**: Extension (light discovery; security-sensitive, so key sudo behaviors were verified locally)
- **Key Findings**:
  - On Apple Silicon, `softwareupdate --install` needs volume-owner credentials even for minor updates; root, Touch ID and NOPASSWD sudo cannot supply them, and without a tty it fails or hangs. macOS updates therefore stay out of the unattended path.
  - The user is in the `admin` group, so `sudo -n -l <cmd>` reports *every* command as permitted (via `%admin ALL=(ALL) ALL`), even when running it would need a password. `-l` cannot be used to decide whether a command will run without a password.
  - A dedicated probe entry (`/usr/bin/true htotheizzo-probe-<hash>`) inside the NOPASSWD rule gives a reliable, harmless, read-free check that the *current* rule is installed: `sudo -k -n /usr/bin/true htotheizzo-probe-<hash>` succeeds only if that exact entry exists. `/etc/sudoers.d/*` files are 0440 root:wheel and unreadable by the user, so content comparison is impossible without sudo.

## Research Log

### Touch ID / morning-notification alternative (discovery, 2026-11-14)
- **Context**: The user first imagined a morning notification + fingerprint + result notification.
- **Sources Consulted**: Apple `pam_tid.c` source, `sudo(8)`, `sudoers(5)`, `softwareupdate(8)`, alerter/terminal-notifier repos, Jamf/BeyondTrust/Macjutsu "super" wiki on Apple Silicon owner credentials.
- **Findings**: pam_tid works from a launchd agent in the Aqua session (no tty check), but needs an unlocked screen and an available sensor; actionable notifications need the third-party `alerter` tap; `softwareupdate` still cannot be authorized by Touch ID.
- **Implications**: Rejected in favor of a scoped NOPASSWD rule (user preference: "a simpler way", fingerprint not required).

### sudoers matching and validation (local verification)
- **Context**: Rule must allow exact commands and arguments only, and be validated before activation.
- **Findings**:
  - `visudo -cf <file>` runs as the unprivileged user and reports `parsed OK` / `syntax error` with exit 0/1 (verified).
  - In sudoers, a command followed by `""` permits it only with no arguments; a command followed by arguments permits only that exact argument list.
  - `/etc/sudoers.d` is `drwxr-xr-x root`, so the user can test for the file's existence but not read it.
  - sudo ignores files in `sudoers.d` whose names contain `.` or end in `~`; the filename `htotheizzo` is safe.
  - `-k` with a command makes sudo ignore cached credentials for that invocation without clearing the cache; with `-n` this gives an exact "would this run with no password?" answer.
  - Binary paths on this Mac: `/usr/sbin/purge`, `/usr/bin/xcodebuild`, `/usr/sbin/diskutil`, `/usr/bin/dscacheutil`, `/usr/bin/killall`, `/usr/libexec/locate.updatedb`, `/usr/sbin/visudo`; `periodic` is absent on macOS 27 (the script already falls back to `locate.updatedb`).
- **Implications**: The script invokes permitted commands by absolute path with exactly the arguments in the rule; the rule is generated from the same in-script list.

### macOS Automatic Updates setting
- **Context**: Requirement 5.4 hint.
- **Findings**: `/Library/Preferences/com.apple.SoftwareUpdate.plist` is readable by the user; `AutomaticallyInstallMacOSUpdates = 1` on this Mac. The key can be absent (never configured, or MDM-managed elsewhere).
- **Implications**: Show the hint only when the key reads exactly `0`; absent/unreadable means "cannot determine", no hint.

### Existing code integration points
- `update()` unattended branch: `sudo -n true` probe, else shadows `sudo` with a skip-and-count function (`SUDO_SKIPPED_COUNT`).
- macOS sudo call sites: `sudo xcodebuild -license accept`, `sudo diskutil verifyVolume /`, `sudo purge`, `sudo periodic daily weekly monthly` / `sudo /usr/libexec/locate.updatedb`, `sudo dscacheutil -flushcache`, `run_with_fallback "sudo killall -HUP mDNSResponder"` (eval, so a shell function shadow applies), `sudo mdutil -E /`, `sudo softwareupdate ...`, `sudo tmutil localsnapshot`, `sudo gem update/cleanup`, `sudo port ...`.
- `mac_spotlight_rebuild` is gated by `should_run spotlight` (default on).
- Completion notifications are sent in one place after `show_error_summary` ("All updates completed successfully" / "Updates completed with N warning(s)").
- `show_status()` already reports the launchd agent and recent runs.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Scoped NOPASSWD sudoers drop-in | One-time `--install-sudoers`; unattended wrapper runs allowlisted commands with `sudo -n` | No prompts, no secrets, no new deps; small diff | Any process as the user can run those exact commands as root | Chosen |
| Touch ID morning flow | alerter prompt + pam_tid | Explicit daily consent | Many moving parts; fails when locked/clamshell; can't do softwareupdate | Rejected |
| Root LaunchDaemon | Separate root job for maintenance | Runs with nobody logged in | Needs root-owned script copy outside repo; same softwareupdate wall | Rejected |
| Keychain password + `--stdinpass` | Store login password for softwareupdate | Script controls OS updates | Weakens security materially | Rejected |

## Design Decisions

### Decision: Single in-script allowlist as source of truth
- **Context**: Rule contents, the unattended wrapper, `--status` and docs must agree.
- **Alternatives Considered**: 1) Separate sudoers template file in repo; 2) Array in `htotheizzo.sh`.
- **Selected Approach**: A bash array of exact command strings in `htotheizzo.sh`; the rule text, probe hash, wrapper matching and help/README list all derive from it.
- **Rationale**: One place to change; drift is detectable via the hash in the probe entry.
- **Trade-offs**: Rule changes require re-running `--install-sudoers` (surfaced by `--status` and by the unattended log).

### Decision: Probe entry for "installed and current"
- **Context**: File is unreadable; `sudo -l` is useless for admin users.
- **Selected Approach**: Include `/usr/bin/true htotheizzo-probe-<hash8>` in the rule, where `<hash8>` is the first 8 hex chars of `shasum -a 256` over the generated rule body (excluding the probe line). Check with `sudo -k -n /usr/bin/true htotheizzo-probe-<hash8>`.
- **Rationale**: Running `true` as root is harmless; the check needs no password and no file access, and fails for missing, outdated or non-effective (e.g. no includedir) rules alike.
- **Follow-up**: Verify on the real machine after install that the probe succeeds and that a stale hash fails.

### Decision: Generalize the unattended shadow `sudo` instead of touching each call site's logic
- **Selected Approach**: Keep the existing shadow function; it now runs `command sudo -n "$@"` when the probe passed and `"$*"` exactly matches an allowlist entry, else skips and counts as today. Call sites only switch to absolute paths and exact argument forms.
- **Rationale**: Smallest change; every current and future sudo call is covered by default-deny.

### Decision: macOS updates handled by reporting, not installing
- **Selected Approach**: In unattended mode, the softwareupdate block lists updates (no sudo), records the pending count, does not attempt installation, and does not count it as a skipped sudo step.

### Decision: Spotlight rebuild opt-in via `spotlight_rebuild=1`
- **Selected Approach**: Replace `should_run spotlight` gating with an explicit opt-in (`spotlight_rebuild=1`, or `only_spotlight=1` which already expresses intent). Not allowlisted.

## Risks & Mitigations
- Root escalation via allowlisted binary — only Apple-signed, root-owned binaries with fixed arguments; `xcodebuild` is a shim but sudo's `env_reset` strips `DEVELOPER_DIR`; no shell, no wildcards, no user-writable paths. Documented in README.
- Rule installed but sudoers lacks `#includedir` — the post-install probe fails and the installer reports "installed but not effective" and rolls back.
- A broken file in `/etc/sudoers.d` could break all sudo — validate with `visudo -cf` before install and `sudo visudo -c` after; on failure restore the backup / remove the file within the same privileged session.
- Command fails as root at 02:00 (e.g. diskutil busy) — existing `|| log "Warning: ..."` pattern.

## References
- `sudo(8)`, `sudoers(5)`, `visudo(8)`, `softwareupdate(8)` man pages (macOS 27.2)
- https://github.com/Macjutsu/super/wiki/Apple-Silicon-Local-Credentials — owner credentials for updates
- https://github.com/apple-oss-distributions/pam_modules/blob/main/modules/pam_tid/pam_tid.c — Touch ID PAM behavior

## Post-review Changes (task-graph sanity review, 2026-11-14)
- Removed `xcodebuild -license accept` from the allowlist: the `/usr/bin/xcodebuild` shim executes the `xcode-select`ed Xcode as root, which may be a user-owned bundle (root escalation).
- Removed `periodic daily weekly monthly`: it runs scripts from local periodic directories that can be user-writable (`/usr/local/etc/periodic`); it is also absent on macOS 27. `mac_system_maintenance` now calls `locate.updatedb` directly.
- Added a test harness prerequisite (constant extraction, recording stubs, non-mock unattended runner), `sudoers_validate_file`, a test-only `HTOTHEIZZO_SUDOERS_FILE` override, strict-mode guards (`grep -c || true`, `defaults read || true`, `if probe; then` form) and explicit gem handling (shadow-function counter is lost inside `$(...)`).
