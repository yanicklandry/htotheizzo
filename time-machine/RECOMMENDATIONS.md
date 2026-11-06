# Time Machine Strategy for Git-Heavy Developers

## Toolkit Overview

This folder is a self-contained backup toolkit built around one idea: if a
file is tracked in git (or trivially reconstructible, like `node_modules`),
Time Machine backing it up is wasted space. Five scripts:

| Script | Purpose | Needs sudo? |
|---|---|---|
| `setup.sh` | Sets the Time Machine destination volume and registers the recommended exclusions (caches, build tools, cloud-synced app data) | Yes |
| `doctor.sh` | Health check: is the backup volume mounted, how much free space is left, how old is the last backup, exclusion audit | No |
| `estimate.sh` | Estimates how large a first backup would be and recommends a drive size before you buy one | No |
| `git-check.sh [dir]` | Scans a directory (default `~/Documents`), lists every git repo under it, and reports which files are *not* tracked by any repo — those are the only ones that actually need a backup | No |
| `backup.sh` | One-time fallback: tars up critical non-git files (SSH/GPG keys, etc.) into `~/backup-YYYY-MM-DD.tar.gz` without needing Time Machine at all | No |

Typical flow: `estimate.sh` to size a drive → `setup.sh` once to configure
exclusions → `doctor.sh` periodically to confirm backups are still healthy →
`git-check.sh` whenever you want to double check nothing outside git is
being missed.

## What Time Machine Actually Protects

For developers who live in git, Time Machine's real value is narrow but critical:

### High Value (back these up)
- `~/.ssh` — private keys are irreplaceable if lost
- `~/.gnupg` — GPG keys
- `~/Library/Keychains` — saved passwords, certificates
- `~/Library/Preferences` — app settings, editor configs, terminal profiles
- `~/Library/Application Support` — browser profiles, local app state
- Any local databases or files not pushed anywhere

### Lower Value (if you have a dotfiles repo in git)
- Shell config (`~/.zshrc`, `~/.bashrc`, etc.)
- Tool configs (`.gitconfig`, `.npmrc`, `.editorconfig`, etc.)

Put these in a **private git repo** — that handles them better than Time Machine.

---

## What to Exclude (saves enormous space)

These directories are reconstructible and bloat your backup unnecessarily:

| Path | Why exclude |
|---|---|
| `~/node_modules` | Reinstall with `npm install` |
| `~/.npm` | npm cache |
| `~/.cache` | General cache |
| `~/Library/Caches` | macOS app caches |
| `~/Library/Developer/Xcode/DerivedData` | Rebuilt by Xcode |
| `~/Library/Developer/CoreSimulator` | iOS simulators |
| `~/.gradle` | Java build cache |
| `~/.m2` | Maven cache |
| `~/.docker` | Docker layers |
| `~/.cargo/registry` | Rust crate cache |
| `~/Library/Containers/com.docker.docker` | Docker VM disk |

Use **Asimov** to automatically exclude all `node_modules` and `vendor/` directories system-wide:
```
brew install asimov
sudo brew services start asimov
```

---

## Recommended Partition Size

Given proper exclusions, a developer backup typically stays under 100 GB.

Your current layout:
- `disk4s1` Backup: 500 GB (92% full with 6-year-old snapshots)
- `disk4s2` DOCS: 1.5 TB

With exclusions applied, 500 GB is more than enough for Time Machine.
Old snapshots (2019-2020) can be deleted with:
```
sudo tmutil delete "/Volumes/Backup/Backups.backupdb/Yanick's MacBook Pro/SNAPSHOT_NAME"
```

---

## The 3-2-1 Rule

| Copy | Where |
|---|---|
| 1 | Your Mac (working files) |
| 2 | External drive via Time Machine (disk4s1) |
| 3 | Off-site: GitHub (code), iCloud/S3 (documents) |

SSH keys and GPG keys should also be stored in a password manager (1Password, Bitwarden) as an additional safeguard.
