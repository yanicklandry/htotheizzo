#!/usr/bin/env bash
# lib/antares-folders.sh
#
# Read-only discovery of antares' category=dev watched folders. Meant to be
# `source`d by time-machine/*.sh scripts (exclude-vendor.sh, estimate.sh,
# setup.sh) - not executed directly, and deliberately does not set `set -e`/
# `-u`/`pipefail` itself so it never changes a sourcing script's shell
# options.
#
# Never opens any antares-owned path for writing. Never resolves $HOME,
# $ANTARES_DIR, or $ANTARES_HOME implicitly - the target home is always an
# explicit argument, so callers (e.g. a sudo-aware setup.sh) can pass a
# different resolved home than this process's own $HOME.
#
# TSV column contract (tab-separated; antares owns this format):
#   name  path  amber_gb  red_gb  refresh_h  [week_gb]  [category]  [method]
# `#`-prefixed and blank lines are skipped. A row whose amber_gb or red_gb is
# not a whole number is skipped (antares' own documented rule). Path may
# start with the literal prefix `~/` or `$TMPDIR/`, expanded against the
# supplied <home> and the real $TMPDIR env var - never `eval`.

# antares_repo_dir <home>
#   Echoes "<ANTARES_DIR or <home>/Developer/2026/antares>".
antares_repo_dir() {
  local home="$1"
  printf '%s\n' "${ANTARES_DIR:-$home/Developer/2026/antares}"
}

# antares_state_dir <home>
#   Echoes "<ANTARES_HOME or <home>/antares>".
antares_state_dir() {
  local home="$1"
  printf '%s\n' "${ANTARES_HOME:-$home/antares}"
}

# _antares_parse_dev_rows <file> <home>
#   Internal helper. Reads <file>, filters to well-formed category=dev rows,
#   expands each row's path against <home>/$TMPDIR, and prints "name\tpath"
#   lines. Never writes to <file>. Returns 0 even if <file> has zero
#   matching rows.
_antares_parse_dev_rows() {
  local file="$1"
  local home="$2"
  local tmpdir="${TMPDIR:-/tmp}"
  tmpdir="${tmpdir%/}"

  local raw_line name path
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    [[ "$raw_line" =~ ^[[:space:]]*#.*$ ]] && continue
    [[ "$raw_line" =~ ^[[:space:]]*$ ]] && continue

    local filtered
    filtered="$(awk -F'\t' '
      {
        name = $1; path = $2; amber = $3; red = $4; category = $7
        if (name == "" || path == "") next
        if (amber !~ /^[0-9]+$/ || red !~ /^[0-9]+$/) next
        if (category != "dev") next
        print name "\t" path
      }
    ' <<< "$raw_line")"
    [[ -z "$filtered" ]] && continue

    IFS=$'\t' read -r name path <<< "$filtered"

    case "$path" in
      '~/'*)
        path="$home/${path#\~/}"
        ;;
      '$TMPDIR/'*)
        path="$tmpdir/${path#\$TMPDIR/}"
        ;;
    esac

    printf '%s\t%s\n' "$name" "$path"
  done < "$file"

  return 0
}

# _antares_name_seen <name> <existing_rows>
#   Internal helper. True (0) if <name> already appears as the first field
#   of any line in <existing_rows> (newline-separated "name\tpath" rows).
_antares_name_seen() {
  local name="$1"
  local existing_rows="$2"
  [[ -z "$existing_rows" ]] && return 1
  local line line_name
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    line_name="${line%%$'\t'*}"
    if [[ "$line_name" == "$name" ]]; then
      return 0
    fi
  done <<< "$existing_rows"
  return 1
}

# read_dev_folders <home>
#   Reads category=dev rows from "$(antares_repo_dir <home>)/watch-folders.tsv"
#   and "$(antares_state_dir <home>)/watch-auto.tsv". Curated rows win on name
#   collision. Expands `~/` and `$TMPDIR/` path prefixes literally against
#   <home> and the real $TMPDIR (never `eval`).
#   stdout: one "name\tpath" line per resolved folder.
#   stderr: nothing on success.
#   exit 0 always (never fails the caller).
# If neither TSV is readable: stderr gets one line ("antares not found:
#   scanning <home>/Developer directly instead") and stdout yields the
#   hardcoded fallback list (currently: "fallback\t<home>/Developer").
read_dev_folders() {
  local home="$1"
  local repo_dir state_dir curated_file auto_file
  repo_dir="$(antares_repo_dir "$home")"
  state_dir="$(antares_state_dir "$home")"
  curated_file="$repo_dir/watch-folders.tsv"
  auto_file="$state_dir/watch-auto.tsv"

  local curated_readable=1 auto_readable=1
  [[ -r "$curated_file" ]] || curated_readable=0
  [[ -r "$auto_file" ]] || auto_readable=0

  if [[ "$curated_readable" -eq 0 && "$auto_readable" -eq 0 ]]; then
    printf 'antares not found: scanning %s/Developer directly instead\n' "$home" >&2
    printf 'fallback\t%s/Developer\n' "$home"
    return 0
  fi

  local curated_rows=""
  if [[ "$curated_readable" -eq 1 ]]; then
    curated_rows="$(_antares_parse_dev_rows "$curated_file" "$home")"
  fi

  local auto_rows=""
  if [[ "$auto_readable" -eq 1 ]]; then
    auto_rows="$(_antares_parse_dev_rows "$auto_file" "$home")"
  fi

  if [[ -n "$curated_rows" ]]; then
    printf '%s\n' "$curated_rows"
  fi

  if [[ -n "$auto_rows" ]]; then
    local line name
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      name="${line%%$'\t'*}"
      if _antares_name_seen "$name" "$curated_rows"; then
        continue
      fi
      printf '%s\n' "$line"
    done <<< "$auto_rows"
  fi

  return 0
}
