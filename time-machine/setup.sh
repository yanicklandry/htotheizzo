#!/usr/bin/env bash
# Time Machine setup: sets destination and adds recommended exclusions.
# Run once with: bash setup.sh

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

# ── set destination ──────────────────────────────────────────────────────────
info "Setting Time Machine destination to $BACKUP_VOLUME ..."
tmutil setdestination "$BACKUP_VOLUME"
success "Destination set."

# ── exclusions ───────────────────────────────────────────────────────────────
EXCLUDES=(
    # build tools and caches
    "$HOME/.npm"
    "$HOME/.cache"
    "$HOME/.docker"
    "$HOME/.gradle"
    "$HOME/.m2"
    "$HOME/.cargo/registry"
    "$HOME/Library/Caches"
    "$HOME/Library/Developer/Xcode/DerivedData"
    "$HOME/Library/Developer/CoreSimulator"
    "$HOME/Library/Containers/com.docker.docker"
    "$HOME/Library/Mail"
    # Application Support: cloud-synced or reconstructible apps
    "$HOME/Library/Application Support/Google"
    "$HOME/Library/Application Support/CrossOver"
    "$HOME/Library/Application Support/Notion"
    "$HOME/Library/Application Support/Claude"
    "$HOME/Library/Application Support/BeeperTexts"
    "$HOME/Library/Application Support/Steam"
    "$HOME/Library/Application Support/Slack"
    "$HOME/Library/Application Support/discord"
    "$HOME/Library/Application Support/Figma"
    "$HOME/Library/Application Support/Framer"
    "$HOME/Library/Application Support/Caches"
    # Email: all stored on cloud servers (Gmail, Proton, iCloud, Outlook...)
    "$HOME/Library/Mail"
    "$HOME/Library/Application Support/protonmail"
    "$HOME/Library/Application Support/Proton Mail"
    "$HOME/Library/Application Support/Proton Meet"
    "$HOME/Library/Application Support/icloudmailagent"
    "$HOME/Library/Application Support/Mimestream"
    "$HOME/Library/Application Support/Airmail 5"
    "$HOME/Library/Application Support/Spark"
    "$HOME/Library/Application Support/com.readdle.smartemail"
    "$HOME/Library/Application Support/Microsoft Outlook"
    "$HOME/Library/Application Support/Thunderbird"
    "$HOME/Library/Application Support/hey"
)

info "Adding exclusions ..."
for path in "${EXCLUDES[@]}"; do
    if [[ ! -e "$path" ]]; then
        continue  # path doesn't exist yet, skip silently
    elif tmutil isexcluded "$path" 2>/dev/null | grep -q '\[Excluded\]'; then
        warn "Already excluded: $path"
    else
        tmutil addexclusion "$path"
        success "Excluded: $path"
    fi
done

# ── enable Time Machine ──────────────────────────────────────────────────────
info "Enabling Time Machine ..."
tmutil enable
success "Time Machine enabled."

echo ""
echo -e "${GREEN}Setup complete.${NC}"
echo "Run './doctor.sh' to verify, or 'sudo tmutil startbackup' to start a backup now."
