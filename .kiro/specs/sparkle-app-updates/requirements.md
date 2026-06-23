# Requirements Document

## Introduction

htotheizzo performs a single-command, unattended update pass across 60+ package managers but currently has no handling for **Sparkle apps** — third-party macOS applications that self-update through the Sparkle framework and are not installed as Homebrew casks. These apps only update when launched and interactively prompted, so they silently fall stale after every run. A colleague's tool, **antares** (`/Users/yanick/Developer/2026/antares`), already performs a per-app Sparkle update through its `bin/update-app.sh` helper (reads the app's Sparkle feed, finds the newest stable release, installs into `/Applications`, relaunches if the app was running).

This feature adds a new macOS-only update section that discovers installed Sparkle apps and delegates their updates to antares, behaving like every other htotheizzo section: graceful per-item failure, a `skip_<name>=1` control, non-interactive execution, and inclusion in the end-of-run summary. antares is treated as an external dependency and is not modified.

## Boundary Context

- **In scope**: Discovering installed Sparkle apps on macOS; delegating each outdated app's update to antares; locating the antares updater; a skip control; warning-tolerant failure handling and summary reporting; macOS-only execution; non-interactive and mock-safe behavior.
- **Out of scope**: Modifying antares (appcast parsing, download, install, relaunch logic remain antares'); report-only or dry-run-only modes (auto-update was chosen); Sparkle apps that are Homebrew casks (already covered by the existing cask update path); Linux and Windows; deciding *which version* is newest or *whether* an app is behind (delegated to antares).
- **Adjacent expectations**: antares' `update-app.sh` is expected to exist and be executable, to accept a single app name/path, to be a no-op when an app is already current, and to perform the install/relaunch itself. htotheizzo only discovers apps and invokes the updater; it does not own version comparison or installation.

## Requirements

### Requirement 1: Sparkle App Discovery

**Objective:** As a developer running an unattended update, I want htotheizzo to find every self-updating Sparkle app on my machine, so that none are missed without me maintaining a list.

#### Acceptance Criteria
1. While running on macOS, when the Sparkle update section executes, the htotheizzo Sparkle updater shall enumerate installed applications and identify those that declare a Sparkle update feed.
2. The htotheizzo Sparkle updater shall include an application in scope only when that application declares a Sparkle update feed reachable over `http` or `https`.
3. If an application does not declare a valid Sparkle update feed, then the htotheizzo Sparkle updater shall exclude it from the update set without logging it as an error.
4. If no Sparkle apps are discovered, then the htotheizzo Sparkle updater shall complete the section without error and report that no Sparkle apps were found.

### Requirement 2: Automatic Update Delegation

**Objective:** As a developer, I want each discovered Sparkle app brought up to its newest stable version automatically, so that running htotheizzo keeps these apps current the same way it keeps package managers current.

#### Acceptance Criteria
1. When a Sparkle app is discovered, the htotheizzo Sparkle updater shall invoke the antares Sparkle updater for that app.
2. When the antares Sparkle updater reports an app is already current, the htotheizzo Sparkle updater shall leave the app unchanged and continue to the next app.
3. When an app is behind its newest stable version, the htotheizzo Sparkle updater shall delegate the download, installation, and (where the app was running) relaunch to the antares Sparkle updater.
4. The htotheizzo Sparkle updater shall not perform appcast parsing, version comparison, or installation itself; these remain owned by antares.

### Requirement 3: antares Availability Resolution

**Objective:** As a developer who may run htotheizzo on machines where antares is not installed, I want the Sparkle section to locate antares or skip cleanly, so that a missing dependency never breaks my update run.

#### Acceptance Criteria
1. The htotheizzo Sparkle updater shall resolve the antares updater location from the `ANTARES_DIR` environment variable when it is set.
2. While `ANTARES_DIR` is unset, the htotheizzo Sparkle updater shall fall back to a known default antares location.
3. If the antares Sparkle updater cannot be found or is not executable, then the htotheizzo Sparkle updater shall skip the Sparkle section and log an informational message, without failing the run.

### Requirement 4: Skip Control

**Objective:** As a developer, I want to exclude Sparkle updates from a run, so that I retain the same per-category control htotheizzo offers for every other tool.

#### Acceptance Criteria
1. Where `skip_sparkle=1` is set, the htotheizzo Sparkle updater shall not discover or update any Sparkle apps.
2. While `skip_sparkle=1` is set, the htotheizzo Sparkle updater shall not invoke the antares Sparkle updater for any app.
3. The skip control shall follow the same `skip_<name>=1` convention used by every other htotheizzo update category.

### Requirement 5: Failure Tolerance and Reporting

**Objective:** As a developer running unattended updates, I want a single failing app to never abort the run and to be visible afterward, so that the run stays safe and auditable.

#### Acceptance Criteria
1. If updating one Sparkle app fails, then the htotheizzo Sparkle updater shall log a warning and continue updating the remaining apps.
2. The htotheizzo Sparkle updater shall not abort the overall htotheizzo run when a Sparkle update fails, preserving strict-mode correctness.
3. When the Sparkle section starts and finishes, the htotheizzo Sparkle updater shall emit log output consistent with other update sections so the activity appears in the run output and summary.
4. If any Sparkle update produced a warning, then that warning shall be visible in the end-of-run summary alongside other warnings.

### Requirement 6: Platform Scope and Non-Interactive Execution

**Objective:** As a developer who runs htotheizzo from cron, CI, and the GUI, I want the Sparkle section to run only where it applies and never block on input, so that automated runs complete unattended.

#### Acceptance Criteria
1. The htotheizzo Sparkle updater shall execute only on the macOS update path and shall not run on Linux or Windows.
2. The htotheizzo Sparkle updater shall run without requiring interactive input during a normal run.
3. While mock mode is active, the htotheizzo Sparkle updater shall not download or install any app and shall leave installed apps unchanged.
4. Where the GUI consumes progress events, the htotheizzo Sparkle updater shall emit a progress label for the Sparkle section consistent with the existing progress-event convention.
