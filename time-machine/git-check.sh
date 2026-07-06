#!/usr/bin/env bash
# Scans a directory (default: ~/Documents) and reports files that are NOT
# tracked by any git repository — these are the ones that truly need a backup.
# Usage: bash git-check.sh [directory]

set -uo pipefail

SCAN_DIR="${1:-$HOME/Documents}"
SCAN_DIR="${SCAN_DIR%/}"  # strip trailing slash

BOLD=$'\033[1m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'; DIM=$'\033[2m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'

header() { echo -e "\n${BOLD}$*${NC}"; }
info()   { echo -e "  ${CYAN}[info]${NC} $*"; }

echo -e "${BOLD}Git Coverage Check${NC} — $(date '+%Y-%m-%d %H:%M')"
echo -e "Scanning: ${CYAN}$SCAN_DIR${NC}"
echo "────────────────────────────────────────────────────────────────────"

[[ -d "$SCAN_DIR" ]] || { echo -e "${RED}Directory not found: $SCAN_DIR${NC}"; exit 1; }

# ── 1. Find all git repos under the scan dir ─────────────────────────────────
header "Git repositories found"

GIT_REPOS=()
while IFS= read -r repo; do
    GIT_REPOS+=("${repo%/.git}")
done < <(find "$SCAN_DIR" -maxdepth 5 -name ".git" -type d 2>/dev/null)

if [[ ${#GIT_REPOS[@]} -eq 0 ]]; then
    info "No git repositories found under $SCAN_DIR"
else
    for repo in "${GIT_REPOS[@]}"; do
        # Count tracked files and get last commit
        cd "$repo" 2>/dev/null || continue
        tracked=$(git ls-files 2>/dev/null | wc -l | tr -d ' ')
        last=$(git log -1 --format="%ar" 2>/dev/null || echo "no commits")
        untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${GREEN}[git]${NC}  ${repo/#$HOME/~}"
        echo -e "         ${DIM}$tracked tracked files, $untracked untracked, last commit: $last${NC}"
        cd - > /dev/null
    done
fi

# ── 2. Find top-level items that are NOT inside any git repo ──────────────────
header "Items NOT in any git repo (need backup)"

NOT_GIT=()
TOTAL_NOT_GIT=0

while IFS= read -r item; do
    # Check if this item is inside any of the known repos
    in_repo=false
    for repo in "${GIT_REPOS[@]}"; do
        if [[ "$item" == "$repo"* ]]; then
            in_repo=true
            break
        fi
    done

    if [[ "$in_repo" == false ]]; then
        sz=$(du -sk "$item" 2>/dev/null | awk '{print $1 * 1024}')
        sz=${sz:-0}
        TOTAL_NOT_GIT=$(( TOTAL_NOT_GIT + sz ))
        NOT_GIT+=("$item")

        # Human size
        if   (( sz >= 1073741824 )); then h=$(printf "%.1f GB" "$(echo "scale=1; $sz/1073741824" | bc)")
        elif (( sz >= 1048576 ));    then h=$(printf "%.1f MB" "$(echo "scale=1; $sz/1048576"    | bc)")
        elif (( sz >= 1024 ));       then h=$(printf "%.1f KB" "$(echo "scale=1; $sz/1024"       | bc)")
        else h="${sz} B"; fi

        printf "  ${YELLOW}[!]${NC}    %-55s %8s\n" "${item/#$HOME/~}" "$h"
    fi
done < <(find "$SCAN_DIR" -maxdepth 1 -mindepth 1 2>/dev/null | sort)

if [[ ${#NOT_GIT[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}Everything in $SCAN_DIR is inside a git repository.${NC}"
fi

# ── 3. Find untracked files inside git repos ──────────────────────────────────
header "Untracked files inside git repos (not committed, not in .gitignore)"

ANY_UNTRACKED=false
for repo in "${GIT_REPOS[@]}"; do
    cd "$repo" 2>/dev/null || continue
    mapfile -t untracked < <(git ls-files --others --exclude-standard 2>/dev/null | head -20)
    if [[ ${#untracked[@]} -gt 0 ]]; then
        ANY_UNTRACKED=true
        echo -e "  ${YELLOW}${repo/#$HOME/~}${NC}"
        for f in "${untracked[@]}"; do
            echo -e "    ${DIM}$f${NC}"
        done
    fi
    cd - > /dev/null
done
$ANY_UNTRACKED || echo -e "  ${GREEN}No untracked files found.${NC}"

# ── 4. Summary ────────────────────────────────────────────────────────────────
header "Summary"

if   (( TOTAL_NOT_GIT >= 1073741824 )); then h=$(printf "%.1f GB" "$(echo "scale=1; $TOTAL_NOT_GIT/1073741824" | bc)")
elif (( TOTAL_NOT_GIT >= 1048576 ));    then h=$(printf "%.1f MB" "$(echo "scale=1; $TOTAL_NOT_GIT/1048576"    | bc)")
else h="${TOTAL_NOT_GIT} B"; fi

echo -e "  Git repos found:          ${#GIT_REPOS[@]}"
echo -e "  Items outside git:        ${#NOT_GIT[@]}  (${h})"
echo ""
if [[ ${#NOT_GIT[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}These files have no git safety net — Time Machine is their only backup.${NC}"
else
    echo -e "  ${GREEN}All files are inside git repos. Time Machine is a secondary safety net here.${NC}"
fi
echo ""
