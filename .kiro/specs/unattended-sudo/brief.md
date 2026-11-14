# Brief: unattended-sudo

## Problem
The daily launchd run (`com.htotheizzo.daily`, 02:00, `--unattended`) has no terminal and no sudo credentials, so every step that needs sudo is skipped (8 steps on 2026-11-14). The user has to remember to do a manual run to get them, and the morning log/notification says "completed successfully" while those steps silently did not run.

## Current State
- In unattended mode, `update()` checks `sudo -n true`; when that fails it shadows `sudo` with a function that logs `Skipped (needs sudo): ...` for every sudo call.
- Skipped steps: `xcodebuild -license accept`, `softwareupdate --install --all`, `diskutil verifyVolume /`, `purge`, `/usr/libexec/locate.updatedb`, `dscacheutil -flushcache`, `killall -HUP mDNSResponder`, `mdutil -E /`.
- `pam_tid.so` is configured directly in `/etc/pam.d/sudo` (no `sudo_local`), which is fine for manual runs but irrelevant for unattended ones.
- Research (2026-11-14): on Apple Silicon, `softwareupdate --install` needs volume-owner credentials (the user's password) even for minor updates; root, Touch ID, and NOPASSWD sudo cannot satisfy it, and without a tty it fails or hangs.

## Desired Outcome
- The 02:00 unattended run performs every sudo maintenance step except macOS updates, with no prompt and no stored password.
- macOS updates stay a manual step: the unattended run keeps skipping `softwareupdate --install` (the user is fine typing the password on an occasional manual run), and ideally reports that OS updates are pending so the user knows a manual run is worth it.
- `mdutil -E /` (full Spotlight reindex) no longer runs on every daily run.
- macOS Automatic Updates (System Settings > General > Software Update > Automatic Updates) is the primary way OS updates get installed, since it handles volume-owner authorization natively. This is a user setting, not code; the script keeps its interactive `softwareupdate --install` as a harmless fallback, and `--status` / the unattended summary may hint when Automatic Updates appears to be off (read-only check, e.g. `defaults read /Library/Preferences/com.apple.SoftwareUpdate`), if that proves reliable.

## Approach
Scoped passwordless sudo via a sudoers drop-in, installed once by the script:
- `htotheizzo.sh --install-sudoers` (and a matching uninstall/status) writes `/etc/sudoers.d/htotheizzo` for the current user listing exact absolute command paths **with exact arguments**, validates it with `visudo -cf` before installing (root:wheel, 0440), and never installs an invalid file.
- In unattended mode, the shadow `sudo` function changes from "always skip" to "try `command sudo -n "$@"`; if not permitted, log the skip". Commands covered by the rule then run; anything else (notably `softwareupdate --install`) is still skipped and counted.
- Rejected: morning notification + Touch ID (alerter + presence detection + second agent: most moving parts, still cannot install macOS updates); Keychain-stored password for `--stdinpass` (weakens security for a convenience step); root LaunchDaemon (needs a root-owned copy of the script outside the repo, same softwareupdate wall).

## Scope
- **In**:
  - `--install-sudoers` / `--uninstall-sudoers` (or equivalent) with `visudo` validation, exact-argument rules, idempotent re-install
  - `--status` shows whether the sudoers rule is installed and valid
  - Unattended shadow-sudo change: run allowed commands via `sudo -n`, skip the rest with the existing log/count
  - Make `mdutil -E /` not run daily (remove it, or gate it behind an explicit opt-in / long interval like the weekly cache schedule)
  - Unattended summary/notification: say how many sudo steps were skipped, and that macOS updates are pending when `softwareupdate --list` (no sudo needed) shows any
  - README/help text and `tech.md` steering update for the new flags and behavior
- **Out**:
  - Installing macOS updates unattended (stays manual)
  - Touch ID / morning notification flow, alerter, presence detection
  - Storing any password in Keychain for this feature
  - Linux/Windows sudo behavior

## Boundary Candidates
- Sudoers rule generation + install/uninstall/status (one-time, privileged setup)
- Unattended runtime behavior (shadow sudo, skip accounting, summary/notification)
- Daily-step hygiene (`mdutil` cadence)

## Out of Boundary
- Moving `pam_tid` to `/etc/pam.d/sudo_local`: a one-time manual system tweak worth doing so Touch ID survives macOS updates for manual runs, but not owned by this spec
- Time Machine `[fail]` lines not reaching the error summary (issue #30)
- Keepalive interval / major-upgrade warning (owned by `sudo-auth`)

## Upstream / Downstream
- **Upstream**: launchd agent install (`--install-launchd`), `UNATTENDED` detection, `send_notification`, `show_error_summary`, `SUDO_SKIPPED_COUNT`
- **Downstream**: any future step needing root must be added to the sudoers rule (document this in steering)

## Existing Spec Touchpoints
- **Extends**: none (new boundary)
- **Adjacent**: `sudo-auth` (interactive sudo keepalive + softwareupdate major-upgrade warning); must not change interactive-run behavior

## Constraints
- Security: rules list exact binaries and exact arguments only; never a wildcard, never a shell, never `htotheizzo.sh` or any user-writable script (that would be a root escalation). Sudoers file must pass `visudo -c` before being moved into place.
- Command paths in the rule must match what the script invokes (absolute paths; `sudo` matches on resolved path + args), so the script should call these with the same absolute paths.
- Interactive (non-unattended) runs keep today's behavior: `sudo -v` with Touch ID, then everything including `softwareupdate`.
- `set -euo pipefail`, `|| log "Warning: ..."` fallback, `should_run`/`skip_*` gating, MOCK_MODE/SKIP_SUDO and `test.sh` must keep working.
- Live checkout discipline: work happens in a worktree, merged via PR.
