#!/usr/bin/env bash
# Time Machine doctor: checks your backup health and reports issues.
# Run as: bash doctor.sh   (no sudo needed for most checks)

set -uo pipefail

BACKUP_VOLUME="/Volumes/Backup"
WARN_FREE_GB=50      # warn if Backup volume has less than this free
WARN_DAYS_SINCE=7    # warn if last backup is older than this many days

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

pass() { echo -e "  ${GREEN}[pass]${NC} $*"; }
fail() { echo -e "  ${RED}[fail]${NC} $*"; ISSUES=$((ISSUES + 1)); }
warn() { echo -e "  ${YELLOW}[warn]${NC} $*"; WARNINGS=$((WARNINGS + 1)); }
info() { echo -e "  ${CYAN}[info]${NC} $*"; }

ISSUES=0
WARNINGS=0

echo -e "${BOLD}Time Machine Doctor${NC} — $(date '+%Y-%m-%d %H:%M')"
echo "────────────────────────────────────────────"

# ── 1. Drive mounted ─────────────────────────────────────────────────────────
echo -e "\n${BOLD}Drive${NC}"
if [[ -d "$BACKUP_VOLUME" ]]; then
    pass "Backup volume mounted at $BACKUP_VOLUME"
else
    fail "Backup volume not found at $BACKUP_VOLUME (drive not plugged in?)"
fi

# ── 2. Disk space ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}Disk space${NC}"
if [[ -d "$BACKUP_VOLUME" ]]; then
    DISK_INFO=$(df -g "$BACKUP_VOLUME" | tail -1)
    TOTAL_GB=$(echo "$DISK_INFO" | awk '{print $2}')
    USED_GB=$(echo  "$DISK_INFO" | awk '{print $3}')
    FREE_GB=$(echo  "$DISK_INFO" | awk '{print $4}')
    PCT=$(echo "$DISK_INFO" | awk '{print $5}')

    info "Total: ${TOTAL_GB}G  Used: ${USED_GB}G  Free: ${FREE_GB}G  ($PCT used)"

    if (( FREE_GB < WARN_FREE_GB )); then
        warn "Only ${FREE_GB}G free (threshold: ${WARN_FREE_GB}G). Consider deleting old snapshots."
    else
        pass "${FREE_GB}G free on backup volume."
    fi
fi

# ── 3. Time Machine destination ──────────────────────────────────────────────
echo -e "\n${BOLD}Time Machine destination${NC}"
TM_DEST=$(tmutil destinationinfo 2>/dev/null | grep "Mount Point" | awk -F': ' '{print $2}' || true)
if [[ -z "$TM_DEST" ]]; then
    TM_NAME=$(tmutil destinationinfo 2>/dev/null | grep "^Name" | head -1 | awk -F': ' '{print $2}' || true)
    if [[ "$TM_NAME" == "Macintosh HD" ]]; then
        fail "Destination is local 'Macintosh HD' snapshot, not the external drive. Run: sudo tmutil setdestination $BACKUP_VOLUME"
    else
        info "Destination: ${TM_NAME:-unknown}"
    fi
else
    if [[ "$TM_DEST" == "$BACKUP_VOLUME"* ]]; then
        pass "Destination points to $BACKUP_VOLUME"
    else
        warn "Destination is '$TM_DEST', not $BACKUP_VOLUME"
    fi
fi

# ── 4. Last backup date ──────────────────────────────────────────────────────
echo -e "\n${BOLD}Last backup${NC}"
LATEST=""
if [[ -d "$BACKUP_VOLUME/Backups.backupdb" ]]; then
    LATEST=$(find "$BACKUP_VOLUME/Backups.backupdb" -maxdepth 2 -type d -name '????-??-??-??????' \
        ! -name '*.inProgress' 2>/dev/null | sort | tail -1)
fi

if [[ -z "$LATEST" ]]; then
    fail "No completed backup found on $BACKUP_VOLUME"
else
    SNAP=$(basename "$LATEST")
    SNAP_DATE="${SNAP:0:4}-${SNAP:5:2}-${SNAP:8:2}"
    TODAY=$(date +%Y-%m-%d)
    DAYS=$(( ( $(date -jf "%Y-%m-%d" "$TODAY" +%s) - $(date -jf "%Y-%m-%d" "$SNAP_DATE" +%s) ) / 86400 ))

    if (( DAYS > WARN_DAYS_SINCE )); then
        warn "Last backup was $DAYS days ago ($SNAP_DATE). Connect your drive more often."
    else
        pass "Last backup: $SNAP_DATE ($DAYS days ago)"
    fi

    # check for stuck inProgress
    STUCK=$(find "$BACKUP_VOLUME/Backups.backupdb" -maxdepth 2 -type d -name '*.inProgress' 2>/dev/null | head -1)
    if [[ -n "$STUCK" ]]; then
        warn "Stuck in-progress backup found: $(basename "$STUCK"). Delete it if it is old."
    fi
fi

# ── 5. Snapshots list ────────────────────────────────────────────────────────
echo -e "\n${BOLD}Snapshots on drive${NC}"
if [[ -d "$BACKUP_VOLUME/Backups.backupdb" ]]; then
    COUNT=$(find "$BACKUP_VOLUME/Backups.backupdb" -maxdepth 2 -type d -name '????-??-??-??????' \
        ! -name '*.inProgress' 2>/dev/null | wc -l | tr -d ' ')
    info "$COUNT completed snapshot(s) found"
    find "$BACKUP_VOLUME/Backups.backupdb" -maxdepth 2 -type d -name '????-??-??-??????' \
        2>/dev/null | sort | while read -r snap; do
        echo "         $(basename "$snap")"
    done
else
    info "No Backups.backupdb found on volume."
fi

# ── 6. Critical files check ──────────────────────────────────────────────────
echo -e "\n${BOLD}Critical local files${NC}"
check_path() {
    local label=$1 path=$2
    if [[ -e "$path" ]]; then
        pass "$label exists ($path)"
    else
        warn "$label not found ($path)"
    fi
}
check_path "SSH keys"   "$HOME/.ssh/id_rsa"
check_path "SSH keys"   "$HOME/.ssh/id_ed25519"
check_path "GPG keys"   "$HOME/.gnupg"
check_path ".gitconfig" "$HOME/.gitconfig"

# ── 7. Exclusions check ──────────────────────────────────────────────────────
echo -e "\n${BOLD}Recommended exclusions${NC}"
SHOULD_EXCLUDE=(
    "$HOME/.npm"
    "$HOME/.cache"
    "$HOME/.docker"
    "$HOME/Library/Caches"
    "$HOME/Library/Developer/Xcode/DerivedData"
    "$HOME/Library/Developer/CoreSimulator"
)
for path in "${SHOULD_EXCLUDE[@]}"; do
    if [[ ! -e "$path" ]]; then
        info "Not present (skipping): $path"
    elif tmutil isexcluded "$path" 2>/dev/null | grep -q '\[Excluded\]'; then
        pass "Excluded: $path"
    else
        warn "Not excluded: $path — run setup.sh to fix"
    fi
done

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────"
if (( ISSUES == 0 && WARNINGS == 0 )); then
    echo -e "${GREEN}All checks passed.${NC}"
elif (( ISSUES == 0 )); then
    echo -e "${YELLOW}${WARNINGS} warning(s), no critical issues.${NC}"
else
    echo -e "${RED}${ISSUES} issue(s), ${WARNINGS} warning(s). Review above.${NC}"
fi
echo ""
