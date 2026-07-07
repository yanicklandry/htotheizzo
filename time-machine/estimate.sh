#!/usr/bin/env bash
# Estimates how much space a first Time Machine backup would need.
# No sudo needed. Large directories may take a minute to scan.

set -uo pipefail

BOLD=$'\033[1m'; CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; DIM=$'\033[2m'; NC=$'\033[0m'

header() { echo -e "\n${BOLD}$*${NC}"; }
row()    { printf "  %-55s %8s\n" "$1" "$2"; }
row_dim(){ printf "  ${DIM}%-55s %8s${NC}\n" "$1" "$2"; }

dir_size() {
    local path=$1
    [[ -e "$path" ]] || { echo "0"; return; }
    local kb
    kb=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
    echo $(( ${kb:-0} * 1024 ))
}

human() {
    local bytes=$1
    if   (( bytes >= 1073741824 )); then printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576 ));    then printf "%.1f MB" "$(echo "scale=1; $bytes/1048576"    | bc)"
    elif (( bytes >= 1024 ));       then printf "%.1f KB" "$(echo "scale=1; $bytes/1024"       | bc)"
    else printf "%d B" "$bytes"
    fi
}

echo -e "${BOLD}Backup Space Estimator${NC} — $(date '+%Y-%m-%d %H:%M')"
echo "Scanning your home folder (this may take a minute)..."
echo "────────────────────────────────────────────────────────────────────"

# ── 1. Standard exclusions ───────────────────────────────────────────────────
header "Excluded: caches and build tools"

TOTAL_EXCL=0

EXCLUSIONS=(
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
)

for path in "${EXCLUSIONS[@]}"; do
    sz=$(dir_size "$path")
    TOTAL_EXCL=$(( TOTAL_EXCL + sz ))
    if (( sz > 0 )); then
        row "${path/#$HOME/~}" "$(human $sz)"
    else
        row_dim "${path/#$HOME/~} (not present)" "-"
    fi
done

NM_TOTAL=0
while IFS= read -r nm; do
    sz=$(dir_size "$nm")
    NM_TOTAL=$(( NM_TOTAL + sz ))
done < <(find "$HOME" -maxdepth 4 -type d -name node_modules -prune 2>/dev/null)
if (( NM_TOTAL > 0 )); then
    row "node_modules/ (all found under ~)" "$(human $NM_TOTAL)"
    TOTAL_EXCL=$(( TOTAL_EXCL + NM_TOTAL ))
fi

# ── 2. Application Support breakdown ────────────────────────────────────────
header "Excluded: ~/Library/Application Support (cloud-synced or reconstructible)"

APP_SUPPORT="$HOME/Library/Application Support"
APPSUP_EXCL=0

# Apps that are cloud-synced, cache-only, or easily reinstalled
APPSUP_SKIP=(
    "Google"            # Chrome: profile synced to Google account
    "CrossOver"         # Wine layer: reinstall from license
    "Notion"            # cloud-synced
    "Claude"            # app cache/logs
    "BeeperTexts"       # cloud-synced chat
    "Steam"             # games: reinstall from library
    "Slack"             # cloud-synced
    "discord"           # cloud-synced
    "Figma"             # cloud-synced
    "Framer"            # cloud-synced
    "Caches"            # general app caches
    "com.docker.docker" # Docker VM
    # email clients: all mail lives on cloud servers
    "protonmail"
    "Proton Mail"
    "Proton Meet"
    "icloudmailagent"
    "Mimestream"
    "Airmail 5"
    "Spark"
    "com.readdle.smartemail"
    "Microsoft Outlook"
    "Thunderbird"
    "hey"
)

for app in "${APPSUP_SKIP[@]}"; do
    path="$APP_SUPPORT/$app"
    sz=$(dir_size "$path")
    APPSUP_EXCL=$(( APPSUP_EXCL + sz ))
    if (( sz > 0 )); then
        row "  $app" "$(human $sz)"
    fi
done
TOTAL_EXCL=$(( TOTAL_EXCL + APPSUP_EXCL ))

echo "  $(printf '%0.s─' {1..65})"
row "Total excluded" "$(human $TOTAL_EXCL)"

# ── 3. Application Support: what remains (worth keeping) ────────────────────
header "Included: ~/Library/Application Support (local-only data)"

APPSUP_KEEP=0
APPSUP_TOTAL=$(dir_size "$APP_SUPPORT")
APPSUP_KEEP=$(( APPSUP_TOTAL - APPSUP_EXCL ))
(( APPSUP_KEEP < 0 )) && APPSUP_KEEP=0

# Show the apps that have meaningful local-only data
APPSUP_WORTH=(
    "Signal"            # local message history — no cloud backup
    "Code"              # VS Code: extensions + local settings
    "com.apple.wallpaper"
)
for app in "${APPSUP_WORTH[@]}"; do
    path="$APP_SUPPORT/$app"
    sz=$(dir_size "$path")
    (( sz == 0 )) && continue
    row "  $app" "$(human $sz)"
done
echo -e "  ${DIM}(plus other smaller app data)${NC}"
row "  Total Application Support kept" "$(human $APPSUP_KEEP)"

# ── 4. Developer: gitignore-aware scan ───────────────────────────────────────
header "Developer folder: gitignore-aware breakdown"

DEV_DIRS=( "$HOME/Developer" "$HOME/Projects" "$HOME/Sites" )
DEV_GITIGNORE_EXCL=0
DEV_TOTAL=0

# Common generated dirs to exclude (union of typical .gitignore patterns)
GENERATED_PATTERNS=( "dist" "build" ".next" ".nuxt" "out" "target" ".build"
                     ".cache" "coverage" ".turbo" ".svelte-kit" "__pycache__"
                     ".pytest_cache" "vendor" ".gradle" "Pods" )

for devdir in "${DEV_DIRS[@]}"; do
    [[ -d "$devdir" ]] || continue
    sz=$(dir_size "$devdir")
    DEV_TOTAL=$(( DEV_TOTAL + sz ))
    row "${devdir/#$HOME/~} (total)" "$(human $sz)"

    # Size of each generated pattern found inside
    for pattern in "${GENERATED_PATTERNS[@]}"; do
        pattern_total=0
        while IFS= read -r found; do
            fsz=$(dir_size "$found")
            pattern_total=$(( pattern_total + fsz ))
        done < <(find "$devdir" -maxdepth 6 -type d -name "$pattern" -prune 2>/dev/null)
        if (( pattern_total > 1048576 )); then  # only show if > 1 MB
            row_dim "    $pattern/" "$(human $pattern_total)"
            DEV_GITIGNORE_EXCL=$(( DEV_GITIGNORE_EXCL + pattern_total ))
        fi
    done
done

DEV_NET=$(( DEV_TOTAL - DEV_GITIGNORE_EXCL ))
(( DEV_NET < 0 )) && DEV_NET=0
echo "  $(printf '%0.s─' {1..65})"
row "  Generated (excluded by .gitignore patterns)" "$(human $DEV_GITIGNORE_EXCL)"
row "  Net Developer backup size" "$(human $DEV_NET)"
echo ""
echo -e "  ${CYAN}Tip:${NC} install ${BOLD}tmignore${NC} to register these automatically with Time Machine:"
echo -e "       brew install tmignore && sudo brew services start tmignore"

TOTAL_EXCL=$(( TOTAL_EXCL + DEV_GITIGNORE_EXCL ))

# ── 5. Other included paths ──────────────────────────────────────────────────
header "Other included paths"

OTHER_PATHS=(
    "$HOME/.ssh"
    "$HOME/.gnupg"
    "$HOME/.config"
    "$HOME/dotfiles"
    "$HOME/.dotfiles"
    "$HOME/Library/Preferences"
    "$HOME/Library/Keychains"
    "$HOME/Documents"
    "$HOME/Desktop"
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Movies"
    "$HOME/Music"
)

TOTAL_INCL=$APPSUP_KEEP
TOTAL_INCL=$(( TOTAL_INCL + DEV_NET ))

for path in "${OTHER_PATHS[@]}"; do
    [[ -e "$path" ]] || continue
    sz=$(dir_size "$path")
    (( sz == 0 )) && continue
    TOTAL_INCL=$(( TOTAL_INCL + sz ))
    row "${path/#$HOME/~}" "$(human $sz)"
done

echo "  $(printf '%0.s─' {1..65})"
row "Total to back up" "$(human $TOTAL_INCL)"

# ── 6. Summary ───────────────────────────────────────────────────────────────
header "Summary"

OTHER_HOME=$(dir_size "$HOME")
COMPRESSED=$(echo "scale=0; $TOTAL_INCL * 70 / 100" | bc)

printf "  %-40s %s\n" "Home folder total:"        "$(human $OTHER_HOME)"
printf "  %-40s %s\n" "Excluded (not backed up):" "$(human $TOTAL_EXCL)"
echo -e "  $(printf '%-40s' 'First backup estimate:')     ${GREEN}$(human $TOTAL_INCL)${NC}"
echo -e "  $(printf '%-40s' 'After compression (~70%):')  ${GREEN}$(human $COMPRESSED)${NC}"
echo ""

header "Drive recommendation"

RECOMMENDED=$(echo "scale=0; $TOTAL_INCL * 3 / 1" | bc)
echo -e "  $(printf '%-40s' 'Recommended drive size (3x history):') $(human $RECOMMENDED)"

BACKUP_VOLUME="/Volumes/Backup"
if [[ -d "$BACKUP_VOLUME" ]]; then
    DISK_INFO=$(df -k "$BACKUP_VOLUME" | tail -1)
    FREE_K=$(echo "$DISK_INFO" | awk '{print $4}')
    FREE_BYTES=$(( FREE_K * 1024 ))
    echo ""
    echo -e "  $(printf '%-40s' "Free space on $BACKUP_VOLUME now:") $(human $FREE_BYTES)"
    if (( FREE_BYTES >= TOTAL_INCL )); then
        echo -e "  ${GREEN}Your drive has enough space for a first backup.${NC}"
    else
        SHORTFALL=$(( TOTAL_INCL - FREE_BYTES ))
        echo -e "  ${RED}Shortfall: $(human $SHORTFALL) - free up space or resize partition.${NC}"
    fi
fi

echo ""
echo "────────────────────────────────────────────────────────────────────"
echo -e "${DIM}Run 'bash git-check.sh ~/Documents' to find files outside git."
echo -e "Run 'sudo bash setup.sh' to register exclusions with Time Machine.${NC}"
echo ""
