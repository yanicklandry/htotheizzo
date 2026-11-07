#!/usr/bin/env bash
# exclude-vendor.sh
#
# Sweeps antares-tracked `category=dev` folders for reconstructible
# vendor/build directories (node_modules, .venv, dist, build, ...) and
# reports what Time Machine would stop backing up. Defaults to --dry-run.
#
# `--apply` is recognized by the CLI here but its actual `tmutil
# addexclusion` logic is task 2.2's job - until that lands, --apply
# behaves identically to --dry-run (report only, exclude nothing) so the
# flag is never a silent no-op that could be mistaken for a working apply.
#
# Usage: exclude-vendor.sh [--dry-run|--apply|--help]
#   --dry-run   Report matches and total bytes. No changes. (default)
#   --apply     Not yet implemented end-to-end (see task 2.2) - currently
#               behaves identically to --dry-run.
#   --help, -h  Show this usage and exit.
#
# Never requires sudo.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/antares-folders.sh
source "$SCRIPT_DIR/lib/antares-folders.sh"
# shellcheck source=lib/vendor-dirs.sh
source "$SCRIPT_DIR/lib/vendor-dirs.sh"

# ── colours ──────────────────────────────────────────────────────────────────
BOLD=$'\033[1m'; CYAN=$'\033[0;36m'; GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'; NC=$'\033[0m'

info()    { echo -e "${CYAN}[info]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }

usage() {
    cat <<'EOF'
Usage: exclude-vendor.sh [--dry-run|--apply|--help]

  --dry-run   Report vendor/build matches and total bytes. Changes
              nothing. (default when no flag is given)
  --apply     Not yet implemented end-to-end - task 2.2 adds the actual
              tmutil exclusion logic. Currently behaves identically to
              --dry-run: reports matches only, excludes nothing.
  --help, -h  Show this usage and exit.
EOF
}

# ── argument parsing ─────────────────────────────────────────────────────────
MODE="dry-run"

case "${1:-}" in
    ""|--dry-run)
        MODE="dry-run"
        ;;
    --apply)
        MODE="apply"
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

if [[ $# -gt 1 ]]; then
    usage >&2
    exit 1
fi

# ── home resolution ──────────────────────────────────────────────────────────
# This script never requires sudo, but if it's invoked under sudo by mistake
# (e.g. copy-pasted alongside setup.sh), resolve the real invoking user's
# home rather than root's - same pattern setup.sh already uses - instead of
# silently scanning the wrong (and likely empty) home directory.
resolve_home() {
    if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        local resolved
        resolved=$(dscl . -read "/Users/$SUDO_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')
        if [[ -n "$resolved" && -d "$resolved" ]]; then
            printf '%s\n' "$resolved"
            return 0
        fi
        warn "Could not resolve home for sudo user '$SUDO_USER' - falling back to \$HOME ($HOME)" >&2
    fi
    printf '%s\n' "$HOME"
}

TARGET_HOME="$(resolve_home)"

# ── size helpers (small local versions of estimate.sh's dir_size/human) ──────
dir_size_bytes() {
    local path="$1"
    [[ -e "$path" ]] || { echo 0; return; }
    local kb
    kb=$(du -sk "$path" 2>/dev/null | awk '{print $1}')
    echo $(( ${kb:-0} * 1024 ))
}

human_bytes() {
    local bytes="$1"
    if   (( bytes >= 1073741824 )); then printf '%.1f GB' "$(echo "scale=1; $bytes/1073741824" | bc)"
    elif (( bytes >= 1048576 ));    then printf '%.1f MB' "$(echo "scale=1; $bytes/1048576"    | bc)"
    elif (( bytes >= 1024 ));       then printf '%.1f KB' "$(echo "scale=1; $bytes/1024"       | bc)"
    else printf '%d B' "$bytes"
    fi
}

# ── sweep ───────────────────────────────────────────────────────────────────
echo -e "${BOLD}Vendor/Build Exclusion Sweep${NC} - $(date '+%Y-%m-%d %H:%M') [$MODE]"
echo "Home: $TARGET_HOME"
echo "────────────────────────────────────────────────────────────────────"

TOTAL_BYTES=0
MATCH_COUNT=0

while IFS=$'\t' read -r folder_name folder_path; do
    [[ -z "${folder_name:-}" ]] && continue

    if [[ ! -e "$folder_path" ]]; then
        warn "Skipping '$folder_name' ($folder_path) - does not exist on disk"
        continue
    fi

    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        sz=$(dir_size_bytes "$match")
        TOTAL_BYTES=$(( TOTAL_BYTES + sz ))
        MATCH_COUNT=$(( MATCH_COUNT + 1 ))
        printf '  %-70s %10s\n' "$match" "$(human_bytes "$sz")"
    done < <(find_vendor_matches "$folder_path")
done < <(read_dev_folders "$TARGET_HOME")

echo "────────────────────────────────────────────────────────────────────"
echo -e "${BOLD}Matches found:${NC} $MATCH_COUNT"
echo -e "${BOLD}Total bytes:${NC}   $TOTAL_BYTES ($(human_bytes "$TOTAL_BYTES"))"
echo ""

if [[ "$MODE" == "apply" ]]; then
    warn "--apply does not yet exclude anything (task 2.2 adds the tmutil logic)."
    warn "This run only reported matches, identical to --dry-run."
else
    info "Dry-run only - no Time Machine exclusion state was changed."
fi
