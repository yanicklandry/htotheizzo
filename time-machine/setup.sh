#!/usr/bin/env bash
# Time Machine setup: sets destination and adds recommended exclusions.
# Run once with: sudo bash setup.sh

set -euo pipefail

BACKUP_VOLUME="/Volumes/Backup"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[setup]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }
die()     { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ── checks ───────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Run with sudo: sudo bash setup.sh"

[[ -d "$BACKUP_VOLUME" ]] || die "Backup volume not mounted at $BACKUP_VOLUME. Plug in the drive first."

# Resolve the *invoking* user's home, not root's. Under sudo, $HOME may already
# be /var/root (sudo -H, or a sudoers with always_set_home), which would make
# every exclusion path below silently non-existent and skipped.
TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" != "root" ]] || die "Could not determine the real user. Run as: sudo bash setup.sh (not from a root shell)."
USER_HOME=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
[[ -d "$USER_HOME" ]] || die "Could not resolve home directory for user '$TARGET_USER'."
info "Applying exclusions for user '$TARGET_USER' ($USER_HOME)"

# ── set destination ──────────────────────────────────────────────────────────
info "Setting Time Machine destination to $BACKUP_VOLUME ..."
tmutil setdestination "$BACKUP_VOLUME"
success "Destination set."

# ── exclusions ───────────────────────────────────────────────────────────────
EXCLUDES=(
    # build tools and caches
    "$USER_HOME/.npm"
    "$USER_HOME/.cache"
    "$USER_HOME/.docker"
    "$USER_HOME/.gradle"
    "$USER_HOME/.m2"
    "$USER_HOME/.cargo/registry"
    "$USER_HOME/Library/Caches"
    "$USER_HOME/Library/Developer/Xcode/DerivedData"
    "$USER_HOME/Library/Developer/CoreSimulator"
    "$USER_HOME/Library/Containers/com.docker.docker"
    "$USER_HOME/Library/Mail"
    # Application Support: cloud-synced or reconstructible apps
    "$USER_HOME/Library/Application Support/Google"
    "$USER_HOME/Library/Application Support/CrossOver"
    "$USER_HOME/Library/Application Support/Notion"
    "$USER_HOME/Library/Application Support/Claude"
    "$USER_HOME/Library/Application Support/BeeperTexts"
    "$USER_HOME/Library/Application Support/Steam"
    "$USER_HOME/Library/Application Support/Slack"
    "$USER_HOME/Library/Application Support/discord"
    "$USER_HOME/Library/Application Support/Figma"
    "$USER_HOME/Library/Application Support/Framer"
    "$USER_HOME/Library/Application Support/Caches"
    # Email: all stored on cloud servers (Gmail, Proton, iCloud, Outlook...)
    "$USER_HOME/Library/Application Support/protonmail"
    "$USER_HOME/Library/Application Support/Proton Mail"
    "$USER_HOME/Library/Application Support/Proton Meet"
    "$USER_HOME/Library/Application Support/icloudmailagent"
    "$USER_HOME/Library/Application Support/Mimestream"
    "$USER_HOME/Library/Application Support/Airmail 5"
    "$USER_HOME/Library/Application Support/Spark"
    "$USER_HOME/Library/Application Support/com.readdle.smartemail"
    "$USER_HOME/Library/Application Support/Microsoft Outlook"
    "$USER_HOME/Library/Application Support/Thunderbird"
    "$USER_HOME/Library/Application Support/hey"
)

info "Adding exclusions ..."
found=0
for path in "${EXCLUDES[@]}"; do
    if [[ ! -e "$path" ]]; then
        continue  # path doesn't exist yet, skip silently
    fi
    found=$((found + 1))
    if tmutil isexcluded "$path" 2>/dev/null | grep -q '\[Excluded\]'; then
        warn "Already excluded: $path"
    else
        tmutil addexclusion "$path"
        success "Excluded: $path"
    fi
done

# If nothing matched, the paths are wrong (bad home resolution) rather than the
# machine genuinely having none of these directories. Fail loudly.
[[ $found -gt 0 ]] || die "None of the ${#EXCLUDES[@]} exclusion paths exist under $USER_HOME. Nothing was excluded."
info "Matched $found of ${#EXCLUDES[@]} exclusion paths."

# ── enable Time Machine ──────────────────────────────────────────────────────
info "Enabling Time Machine ..."
tmutil enable
success "Time Machine enabled."

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo "Run './doctor.sh' to verify, or 'sudo tmutil startbackup' to start a backup now."
