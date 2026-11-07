#!/usr/bin/env bash
# exclude-vendor.sh
#
# Sweeps antares-tracked `category=dev` folders for reconstructible
# vendor/build directories (node_modules, .venv, dist, build, ...) and
# either reports what Time Machine would stop backing up (--dry-run,
# the default) or actually excludes those matches (--apply).
#
# In apply mode, each match is checked with `tmutil isexcluded` before
# `tmutil addexclusion` is ever called - an already-excluded match is
# skipped rather than re-applied, which makes repeated --apply runs
# idempotent (a second run against unchanged folders reports 0 newly
# excluded).
#
# Usage: exclude-vendor.sh [--dry-run|--apply|--install-launchd|--help]
#   --dry-run         Report matches and total bytes. No changes. (default)
#   --apply           Exclude every match from Time Machine (idempotent - an
#                      already-excluded match is skipped, not re-applied).
#   --install-launchd Install (or re-install) a per-user launchd agent that
#                      runs `exclude-vendor.sh --apply` daily. Idempotent -
#                      unloads any previously-installed job with the same
#                      label before loading the freshly-written one, so
#                      running this twice in a row leaves exactly one job
#                      loaded.
#   --help, -h        Show this usage and exit.
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
Usage: exclude-vendor.sh [--dry-run|--apply|--install-launchd|--help]

  --dry-run         Report vendor/build matches and total bytes. Changes
                     nothing. (default when no flag is given)
  --apply           Exclude every matched path from Time Machine. Checks
                     `tmutil isexcluded` first, so already-excluded matches
                     are skipped rather than re-applied (idempotent). Never
                     uses sudo.
  --install-launchd Install (or re-install) a per-user launchd agent that
                     runs this script with --apply once a day. Idempotent -
                     safe to run more than once.
  --help, -h        Show this usage and exit.
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
    --install-launchd)
        MODE="install-launchd"
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

# ── launchd self-install ──────────────────────────────────────────────────────
# Installs a per-user launchd agent that runs this script with --apply once a
# day. Mirrors antares' bin/install.sh __HOME__/__SCRIPT__/__PROG__ template
# substitution and launchctl bootout-then-bootstrap sequence, so re-running
# this twice in a row leaves exactly one job loaded rather than two.
install_launchd() {
    local label="io.github.yanicklandry.htotheizzo.exclude-vendor"
    local template="$SCRIPT_DIR/launchd/$label.plist.template"
    local dest_dir="$TARGET_HOME/Library/LaunchAgents"
    local dest_plist="$dest_dir/$label.plist"
    local script_path="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
    local prog="/bin/bash"

    if [[ ! -f "$template" ]]; then
        warn "Template not found: $template"
        return 1
    fi

    mkdir -p "$dest_dir"
    sed -e "s|__HOME__|$TARGET_HOME|g" \
        -e "s|__SCRIPT__|$script_path|g" \
        -e "s|__PROG__|$prog|g" \
        "$template" > "$dest_plist"

    # Idempotent re-install: unload any previously-installed job with this
    # label first, then load the freshly-written plist. Without the unload,
    # a second `--install-launchd` run would not duplicate the job (launchctl
    # bootstrap refuses an already-loaded label), but unloading first keeps
    # the running job's in-memory definition in sync with what's on disk.
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$dest_plist"

    success "Installed launchd job '$label'"
    echo "  plist   : $dest_plist"
    echo "  script  : $script_path --apply"
    echo "  schedule: daily at 03:00"
    echo "  logs    : $TARGET_HOME/logs/htotheizzo-exclude-vendor.{out,err}.log"
}

if [[ "$MODE" == "install-launchd" ]]; then
    install_launchd
    exit $?
fi

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
EXCLUDED_COUNT=0
SKIPPED_COUNT=0

# is_already_excluded <path>
#   Same `tmutil isexcluded` + grep-for-[Excluded] convention setup.sh
#   already uses, kept consistent here rather than re-invented.
is_already_excluded() {
    tmutil isexcluded "$1" 2>/dev/null | grep -q '\[Excluded\]'
}

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

        if [[ "$MODE" == "apply" ]]; then
            if is_already_excluded "$match"; then
                SKIPPED_COUNT=$(( SKIPPED_COUNT + 1 ))
                printf '  %-70s %10s  %s\n' "$match" "$(human_bytes "$sz")" "[already excluded]"
            else
                tmutil addexclusion "$match"
                EXCLUDED_COUNT=$(( EXCLUDED_COUNT + 1 ))
                printf '  %-70s %10s  %s\n' "$match" "$(human_bytes "$sz")" "[excluded]"
            fi
        else
            printf '  %-70s %10s\n' "$match" "$(human_bytes "$sz")"
        fi
    done < <(find_vendor_matches "$folder_path")
done < <(read_dev_folders "$TARGET_HOME")

echo "────────────────────────────────────────────────────────────────────"
echo -e "${BOLD}Matches found:${NC} $MATCH_COUNT"
echo -e "${BOLD}Total bytes:${NC}   $TOTAL_BYTES ($(human_bytes "$TOTAL_BYTES"))"
echo ""

if [[ "$MODE" == "apply" ]]; then
    echo -e "${BOLD}Excluded:${NC} $EXCLUDED_COUNT"
    echo -e "${BOLD}Skipped (already excluded):${NC} $SKIPPED_COUNT"
    success "Apply complete - $EXCLUDED_COUNT newly excluded, $SKIPPED_COUNT already excluded."
else
    info "Dry-run only - no Time Machine exclusion state was changed."
fi
