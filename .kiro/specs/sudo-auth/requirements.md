# Requirements Document

## Introduction
htotheizzo.sh has two sudo/auth UX issues on macOS that cause unnecessary friction:

1. **Excessive Touch ID prompts**: `keep_sudo_alive()` refreshes sudo credentials every 50 seconds, far more frequently than the 5-minute sudo credential timeout, triggering redundant Touch ID prompts during a single run.
2. **Silent major OS upgrade**: `sudo softwareupdate --install --all` can silently install a major OS upgrade that requires an interactive password, surprising the user mid-run with no prior warning.

This feature delivers two focused fixes in `htotheizzo.sh` to reduce unnecessary prompts and surface the major-upgrade warning at the right time.

## Boundary Context
- **In scope**: `keep_sudo_alive()` refresh interval; `softwareupdate` major-upgrade detection and warning in `htotheizzo.sh`
- **Out of scope**: PAM or sudo configuration changes, suppression of the macOS interactive upgrade password, changes to other sudo calls in the script, Linux/Windows-specific code paths
- **Adjacent expectations**: The initial `sudo -v` auth gate (invoked before `keep_sudo_alive()` is spawned) runs unchanged; this feature does not modify or remove it

## Requirements

### Requirement 1: Reduced Keepalive Refresh Interval

**Objective:** As a macOS user running htotheizzo.sh, I want sudo credentials refreshed at an interval aligned with the 5-minute credential window, so that Touch ID is prompted at most once per credential window.

#### Acceptance Criteria
1. While `keep_sudo_alive()` is running, htotheizzo.sh shall refresh sudo credentials no more than once every 240 seconds, providing a ~60-second margin before the 5-minute sudo timeout expires.
2. The htotheizzo.sh shall not prompt the user for sudo authentication more than once per 5-minute credential window during a normal script run.
3. When running on Linux or other non-macOS platforms, htotheizzo.sh shall maintain equivalent keepalive behavior with no functional regression.

### Requirement 2: Major OS Upgrade Detection and Warning

**Objective:** As a macOS user, I want to be clearly warned before htotheizzo.sh installs a major OS upgrade, so that I am not surprised by an unexpected interactive password prompt mid-run.

#### Acceptance Criteria
1. When `softwareupdate --list` output contains an available update whose major version number differs from the current macOS major version, htotheizzo.sh shall print a prominent warning before attempting installation.
2. When a major OS upgrade is detected, the warning shall state that installation will require an interactive password that bypasses sudo credential caching.
3. When a major OS upgrade is detected, the warning shall inform the user that setting `skip_softwareupdate_major=1` will skip major OS upgrades and install only recommended updates instead.
4. If `softwareupdate --list` output contains no major OS upgrades, htotheizzo.sh shall proceed to installation without printing a major-upgrade warning.
5. The major upgrade detection shall use a resilient heuristic so that minor changes in `softwareupdate --list` formatting do not break detection.
6. Where `skip_softwareupdate_major=1` is set, htotheizzo.sh shall not print the major-upgrade warning (since major upgrades will not be installed).
