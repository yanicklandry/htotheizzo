#!/usr/bin/env bash
# One-time backup: copies critical non-git files to a dated archive.
# Safe to run as your normal user (no sudo needed).
# Output: ~/backup-YYYY-MM-DD.tar.gz

set -euo pipefail

DATE=$(date +%Y-%m-%d)
DEST="$HOME/backup-$DATE.tar.gz"

# ── colours ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${CYAN}[backup]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}  $*"; }

# ── what to capture ──────────────────────────────────────────────────────────
# Paths are relative to $HOME so the archive is self-contained.
INCLUDE=(
    ".ssh"
    ".gnupg"
    ".gitconfig"
    ".zshrc"
    ".zprofile"
    ".bashrc"
    ".bash_profile"
    ".profile"
    ".npmrc"
    ".editorconfig"
    ".hushlogin"
)

# Optional: also grab a dotfiles folder if it exists
[[ -d "$HOME/dotfiles" ]]    && INCLUDE+=("dotfiles")
[[ -d "$HOME/.dotfiles" ]]   && INCLUDE+=(".dotfiles")
[[ -d "$HOME/.config" ]]     && INCLUDE+=(".config")

# ── build tar args ───────────────────────────────────────────────────────────
TAR_ARGS=()
for item in "${INCLUDE[@]}"; do
    full="$HOME/$item"
    if [[ -e "$full" ]]; then
        TAR_ARGS+=("$item")
        info "Including: ~/$item"
    else
        warn "Skipping (not found): ~/$item"
    fi
done

[[ ${#TAR_ARGS[@]} -eq 0 ]] && { echo "Nothing to back up."; exit 1; }

# ── create archive ───────────────────────────────────────────────────────────
info "Creating archive at $DEST ..."
cd "$HOME"
tar -czf "$DEST" "${TAR_ARGS[@]}"

SIZE=$(du -sh "$DEST" | cut -f1)
success "Done. Archive: $DEST ($SIZE)"

echo ""
echo "Store this file in a safe place (password manager, encrypted USB, private cloud)."
echo "To inspect contents: tar -tzf $DEST"
echo "To restore:          tar -xzf $DEST -C ~/"
