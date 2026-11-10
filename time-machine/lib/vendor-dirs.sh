#!/usr/bin/env bash
# lib/vendor-dirs.sh
#
# Canonical list of reconstructible vendor/build directory names, and the
# one matcher implementation used to find them. Meant to be `source`d by
# time-machine/*.sh scripts (exclude-vendor.sh, estimate.sh, git-check.sh) -
# not executed directly, and deliberately does not set `set -e`/`-u`/
# `pipefail` itself so it never changes a sourcing script's shell options.
#
# VENDOR_DIR_NAMES is the single canonical source for "what counts as a
# vendor/build directory" - both find_vendor_matches (walks a root) and
# is_vendor_dir_path (checks a single path) are backed by this one array;
# neither function keeps its own independent copy of the list.

VENDOR_DIR_NAMES=(
  node_modules
  .venv
  venv
  target
  dist
  build
  .next
  __pycache__
)

# find_vendor_matches <root>
#   Walks <root> for directories named in VENDOR_DIR_NAMES, pruning at the
#   first match (never descends into a matched directory looking for
#   nested matches). Never descends into, reports, or acts on anything
#   under a `.git` directory. Never returns <root> itself, even if <root>'s
#   own basename happens to match one of the vendor names.
#   stdout: one absolute matched path per line (possibly empty).
#   stderr: nothing.
#   exit 0 always; produces no output (not an error) if <root> does not
#   exist or is not a directory.
find_vendor_matches() {
  local root="$1"
  [[ -d "$root" ]] || return 0

  local -a name_match=()
  local name
  for name in "${VENDOR_DIR_NAMES[@]}"; do
    if [[ ${#name_match[@]} -gt 0 ]]; then
      name_match+=(-o)
    fi
    name_match+=(-name "$name")
  done

  find "$root" -mindepth 1 \
    \( -type d -name .git -prune \) -o \
    \( -type d \( "${name_match[@]}" \) -print -prune \) -o \
    -true

  return 0
}

# is_vendor_dir_path <path>
#   True (exit 0) if any path component of <path> is a member of
#   VENDOR_DIR_NAMES; false (exit 1) otherwise. Backed by the same
#   VENDOR_DIR_NAMES array as find_vendor_matches - callers that filter a
#   path list (e.g. git-check.sh) rather than walk a root use this instead.
is_vendor_dir_path() {
  local path="$1"
  local name
  for name in "${VENDOR_DIR_NAMES[@]}"; do
    case "/$path/" in
      */"$name"/*)
        return 0
        ;;
    esac
  done
  return 1
}
