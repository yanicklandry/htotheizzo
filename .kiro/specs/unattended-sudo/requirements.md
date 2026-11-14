# Requirements Document

## Project Description (Input)
Let the daily unattended launchd run of htotheizzo perform its sudo maintenance steps without a prompt or stored password, via a one-time, narrowly scoped sudoers drop-in installed by `htotheizzo.sh --install-sudoers` (validated with visudo; exact binaries and arguments only). In unattended mode, sudo calls are attempted non-interactively (`sudo -n`) and only skipped when not permitted. macOS updates stay out of the unattended path (Apple Silicon needs volume-owner credentials): macOS Automatic Updates is the primary mechanism, the interactive `softwareupdate --install` remains a fallback, and the unattended run reports pending OS updates. The full Spotlight reindex (`mdutil -E /`) stops running daily. See brief.md for problem, scope, constraints and rejected alternatives.

## Introduction
The daily unattended run of htotheizzo (launchd agent, no terminal) currently skips every maintenance step that needs administrator rights, so the user must remember to do manual runs and the completion notification reports success even though those steps never ran. This feature lets the user grant, once, a narrowly scoped permission for a fixed list of low-risk maintenance commands so the unattended run can perform them without any prompt or stored password. macOS system updates are deliberately kept out of the unattended path: on Apple Silicon they need the account owner's password, so they are left to macOS Automatic Updates (a user setting) and to interactive runs, while the unattended run reports when they are pending. The full Spotlight index rebuild stops running on every run.

## Boundary Context
- **In scope**:
  - A one-time install, uninstall and status check for the scoped administrator permission (macOS only)
  - The fixed list of permitted maintenance commands: boot volume verification, memory purge, locate database update, DNS cache flush, and mDNSResponder restart
  - Unattended-run behavior for steps that need administrator rights: run when permitted, skip and report when not
  - Reporting pending macOS updates in the unattended run's log, summary and notification
  - Making the full Spotlight index rebuild opt-in instead of default
  - Help text, README and steering documentation for the above
- **Out of scope**:
  - Installing macOS updates during unattended runs
  - Touch ID or any other interactive prompt during unattended runs; morning notification flows
  - Storing any password (Keychain or otherwise) for this feature
  - Granting permission for Xcode license acceptance (runs a possibly user-owned Xcode as root), the periodic maintenance scripts (run scripts from possibly user-writable directories), Ruby gem updates, MacPorts, Time Machine local snapshots, Spotlight rebuild, or any other step not in the fixed list; these stay attended-only
  - Changing the system's Touch ID-for-sudo configuration
  - Linux and Windows behavior
- **Adjacent expectations**:
  - The launchd agent installation and unattended-mode detection already exist and are not changed beyond what this feature needs
  - Interactive (attended) runs keep their current behavior, including the existing keepalive and major-upgrade warning owned by the `sudo-auth` spec
  - Turning on macOS Automatic Updates is a user action in System Settings; htotheizzo does not change that setting

## Requirements

### Requirement 1: Install the scoped permission
**Objective:** As the Mac's owner, I want a single command that grants passwordless administrator rights for only the fixed list of maintenance commands, so that the daily unattended run can perform them without exposing broader root access.

#### Acceptance Criteria
1. When the user runs htotheizzo with the install-permission option on macOS, htotheizzo shall create a permission rule for the current user that covers exactly the fixed list of maintenance commands, each with its exact arguments.
2. When installing the permission rule, htotheizzo shall validate the rule's syntax before activating it.
3. If the rule fails validation, then htotheizzo shall not activate it, shall leave any previously active rule unchanged, and shall exit with a non-zero status and an explanatory message.
4. When the permission rule is installed successfully, htotheizzo shall print the list of commands it permits and confirm the installed location.
5. When the install-permission option is run again, htotheizzo shall replace the existing rule with the current one and produce the same result as a first install (idempotent).
6. The permission rule shall not permit any shell, any command with wildcard or arbitrary arguments, htotheizzo itself, or any file the user can modify without administrator rights.
7. The installed permission rule shall be owned by the administrator account and not be writable by the user.
8. If the install-permission option is run on a non-macOS system, then htotheizzo shall exit with a non-zero status and a message that the option is macOS only.
9. The install-permission option shall require the user's administrator authentication once, interactively, and shall not store any password.

### Requirement 2: Remove and inspect the scoped permission
**Objective:** As the Mac's owner, I want to remove the permission and see whether it is in place, so that I stay in control of what the daily run can do as administrator.

#### Acceptance Criteria
1. When the user runs htotheizzo with the uninstall-permission option, htotheizzo shall remove the permission rule if present and confirm the removal.
2. If no permission rule is installed when the uninstall-permission option is run, then htotheizzo shall report that nothing was installed and exit successfully.
3. When the user runs htotheizzo with the status option, htotheizzo shall report whether the permission rule is installed.
4. When the status option runs and the installed rule differs from the rule the current htotheizzo version would install, htotheizzo shall report that the rule is outdated and suggest re-running the install-permission option.

### Requirement 3: Unattended runs perform permitted administrator steps
**Objective:** As a user relying on the daily automatic run, I want permitted maintenance steps to actually run and the rest to be clearly reported, so that the daily run is complete and its report is honest.

#### Acceptance Criteria
1. While running unattended, when a step needs administrator rights and that exact command is permitted, htotheizzo shall run the step without prompting.
2. While running unattended, if a step needs administrator rights and is not permitted, then htotheizzo shall skip the step, log it as skipped, and count it toward the skipped-step total.
3. While running unattended, htotheizzo shall never display an authentication prompt and shall never wait for input.
4. While running unattended without the permission rule installed, htotheizzo shall behave as it does today: every step needing administrator rights is skipped, logged and counted.
5. When an unattended run finishes with one or more skipped administrator steps, htotheizzo shall state the number of skipped steps in the log and in the completion notification.
6. If a permitted step runs and fails, then htotheizzo shall log a warning and continue with the remaining steps, consistent with other step failures.

### Requirement 4: Attended runs are unchanged
**Objective:** As a user running htotheizzo by hand, I want the same behavior as today, so that this feature does not disrupt manual runs.

#### Acceptance Criteria
1. While running attended, htotheizzo shall request administrator authentication once at the start and perform all administrator steps, including macOS updates, as it does today.
2. Where the permission rule is installed, htotheizzo shall still behave as described in 4.1 for attended runs.
3. While running in mock mode or with the sudo-skip setting, htotheizzo shall not request authentication and shall not run any administrator command, as today.

### Requirement 5: macOS updates during unattended runs
**Objective:** As a user, I want the daily run to tell me when macOS updates are waiting instead of silently skipping them, so that I know when to update.

#### Acceptance Criteria
1. While running unattended, htotheizzo shall not install macOS updates.
2. While running unattended, when macOS updates are available, htotheizzo shall log the list of available updates and include in the completion notification that macOS updates are pending.
3. While running unattended, when no macOS updates are available, htotheizzo shall not mention pending macOS updates in the completion notification.
4. Where htotheizzo can reliably determine that macOS Automatic Updates installation is turned off, htotheizzo shall log a hint recommending turning it on in System Settings; where it cannot determine the setting reliably, it shall not show the hint.
5. The skipped macOS update installation shall not be counted as a failure in the error summary.

### Requirement 6: Spotlight index rebuild is opt-in
**Objective:** As a user, I want the full Spotlight index rebuild to run only when I ask for it, so that daily runs do not force an expensive reindex.

#### Acceptance Criteria
1. htotheizzo shall not rebuild the Spotlight index unless the user explicitly requests it for that run.
2. When the user explicitly requests a Spotlight rebuild during an attended run, htotheizzo shall rebuild the Spotlight index as it does today.
3. The help text shall document how to request a Spotlight rebuild.

### Requirement 7: Documentation
**Objective:** As a user, I want the new options and their security trade-offs documented, so that I can decide to enable them knowingly.

#### Acceptance Criteria
1. The help text shall list the install-permission and uninstall-permission options with a one-line description each.
2. The README shall describe the permitted command list, the security trade-off (any process running as the user can run those exact commands as administrator), how to remove the permission, and that macOS updates are left to macOS Automatic Updates or attended runs.
3. The project steering shall state that any new step needing administrator rights during unattended runs must be added to the permitted list explicitly and must satisfy 1.6.
