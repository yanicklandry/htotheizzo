#!/usr/bin/env bash
# lib/smoke-test.sh
#
# Permanent, repo-committed regression check for lib/antares-folders.sh and
# lib/vendor-dirs.sh (the only shared, reusable logic in time-machine/).
# Builds throwaway TSV and directory-tree fixtures under mktemp, exercises
# both libraries' documented contracts against them, and prints a PASS/FAIL
# line per assertion. Exits 0 only if every assertion passed.
#
# Usage: bash lib/smoke-test.sh
#
# No external test framework - plain bash, consistent with the rest of
# time-machine/ (no npm/pytest/etc. in this repo for shell code).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./antares-folders.sh
source "$SCRIPT_DIR/antares-folders.sh"
# shellcheck source=./vendor-dirs.sh
source "$SCRIPT_DIR/vendor-dirs.sh"

BOLD=$'\033[1m'; GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; DIM=$'\033[2m'; NC=$'\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  ${GREEN}[PASS]${NC} %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  ${RED}[FAIL]${NC} %s\n" "$1"
  if [[ -n "${2:-}" ]]; then
    printf "         ${DIM}%s${NC}\n" "$2"
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected: [$expected]  actual: [$actual]"
  fi
}

# Exact-line matching (grep -x), not substring, so a shorter path that is a
# prefix of another reported path (e.g. ".../dist" vs ".../dist/target")
# can never produce a false match.
assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if grep -qxF -- "$needle" <<< "$haystack"; then
    pass "$desc"
  else
    fail "$desc" "expected to find line: [$needle]"
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if grep -qxF -- "$needle" <<< "$haystack"; then
    fail "$desc" "did not expect to find line: [$needle]"
  else
    pass "$desc"
  fi
}

# Substring matching - only for needles that are deliberately not a whole
# output line (e.g. a bare name expected to be absent anywhere in a blob of
# "name\tpath" rows, or a notice fragment inside a longer stderr message).
assert_substr_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    pass "$desc"
  else
    fail "$desc" "expected to find substring: [$needle]"
  fi
}

assert_substr_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if grep -qF -- "$needle" <<< "$haystack"; then
    fail "$desc" "did not expect to find substring: [$needle]"
  else
    pass "$desc"
  fi
}

assert_true() {
  local desc="$1"
  shift
  if "$@"; then
    pass "$desc"
  else
    fail "$desc" "command: $*"
  fi
}

assert_false() {
  local desc="$1"
  shift
  if ! "$@"; then
    pass "$desc"
  else
    fail "$desc" "command: $* (expected non-zero exit)"
  fi
}

# ---------------------------------------------------------------------------
# Fixture setup (cleaned up on exit, success or failure)
# ---------------------------------------------------------------------------

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

TSV_HOME="$TMP_ROOT/tsv-home"
NO_TSV_HOME="$TMP_ROOT/no-tsv-home"
FIXTURE_TREE="$TMP_ROOT/fixture-tree"

mkdir -p "$TSV_HOME/Developer/2026/antares"
mkdir -p "$TSV_HOME/antares"
mkdir -p "$NO_TSV_HOME"
mkdir -p "$FIXTURE_TREE"

# Curated TSV: wins the "collision_proj" name collision against watch-auto.tsv.
CURATED_TSV="$TSV_HOME/Developer/2026/antares/watch-folders.tsv"
{
  printf '# curated dev folders\n'
  printf '\n'
  printf 'collision_proj\t~/collision_curated\t5\t10\t24\t\tdev\n'
} > "$CURATED_TSV"

# Auto TSV: colliding row (must lose), a non-dev category row (must be
# excluded), a fractional-threshold row (must be skipped per antares' own
# "a row with a fraction is ignored" rule), a normal row, and a $TMPDIR/ row.
AUTO_TSV="$TSV_HOME/antares/watch-auto.tsv"
{
  printf 'collision_proj\t~/collision_auto\t3\t6\t24\t\tdev\n'
  printf 'nondev_proj\t~/nondev_dir\t5\t10\t24\t\tai\n'
  printf 'fractional_proj\t~/fractional_dir\t2.5\t10\t24\t\tdev\n'
  printf 'normal_proj\t~/normal_dir\t5\t10\t24\t\tdev\n'
  printf 'tmp_proj\t$TMPDIR/tmp_proj_dir\t5\t10\t24\t\tdev\n'
} > "$AUTO_TSV"

echo "${BOLD}lib/antares-folders.sh and lib/vendor-dirs.sh smoke test${NC}"
echo "Fixtures under: $TMP_ROOT"
echo "────────────────────────────────────────────────────────────────────"
echo
echo "${BOLD}read_dev_folders: TSV fixtures${NC}"

DEV_FOLDERS_OUTPUT="$(read_dev_folders "$TSV_HOME" 2>/dev/null)"

# 1) Name collision: curated row wins, auto row for the same name is ignored.
assert_contains \
  "collision: curated row wins (collision_proj -> collision_curated)" \
  "$DEV_FOLDERS_OUTPUT" \
  "$(printf 'collision_proj\t%s/collision_curated' "$TSV_HOME")"

assert_substr_not_contains \
  "collision: colliding auto row is ignored (collision_auto never appears)" \
  "$DEV_FOLDERS_OUTPUT" \
  "collision_auto"

# 2) category other than dev is excluded.
assert_substr_not_contains \
  "category!=dev row (nondev_proj, category=ai) is excluded" \
  "$DEV_FOLDERS_OUTPUT" \
  "nondev_proj"

# 3) Fractional threshold row is skipped.
assert_substr_not_contains \
  "fractional threshold row (fractional_proj, amber_gb=2.5) is skipped" \
  "$DEV_FOLDERS_OUTPUT" \
  "fractional_proj"

# Sanity: a well-formed, non-colliding row still passes through untouched.
assert_contains \
  "normal dev row (normal_proj) passes through" \
  "$DEV_FOLDERS_OUTPUT" \
  "$(printf 'normal_proj\t%s/normal_dir' "$TSV_HOME")"

# ~/ and $TMPDIR/ expansion is literal, not eval'd.
EXPECTED_TMPDIR="${TMPDIR:-/tmp}"
EXPECTED_TMPDIR="${EXPECTED_TMPDIR%/}"
assert_contains \
  "\$TMPDIR/ prefix expands literally against the real \$TMPDIR" \
  "$DEV_FOLDERS_OUTPUT" \
  "$(printf 'tmp_proj\t%s/tmp_proj_dir' "$EXPECTED_TMPDIR")"

echo
echo "${BOLD}read_dev_folders: no-TSV fallback case${NC}"

FALLBACK_STDOUT="$(read_dev_folders "$NO_TSV_HOME" 2>/dev/null)"
FALLBACK_STDERR="$(read_dev_folders "$NO_TSV_HOME" 2>&1 1>/dev/null)"

assert_eq \
  "fallback: stdout is exactly the hardcoded fallback row" \
  "$(printf 'fallback\t%s/Developer' "$NO_TSV_HOME")" \
  "$FALLBACK_STDOUT"

assert_substr_contains \
  "fallback: stderr carries the 'antares not found' notice" \
  "$FALLBACK_STDERR" \
  "antares not found"

echo
echo "${BOLD}find_vendor_matches / is_vendor_dir_path: directory-tree fixtures${NC}"

# root1: nested dist/node_modules (prune-at-first-match), a .git/node_modules
# exclusion alongside a sibling non-.git vendor dir ("build"), and a
# non-vendor path for the negative case.
ROOT1="$FIXTURE_TREE/root1"
mkdir -p "$ROOT1/.git/node_modules"
mkdir -p "$ROOT1/build"
mkdir -p "$ROOT1/dist/node_modules"
mkdir -p "$ROOT1/normal/subdir"
touch "$ROOT1/normal/file.txt"

# root2: the scanned root's own basename is itself a vendor name ("dist");
# the root must never be returned, only a genuine match found inside it.
ROOT2="$FIXTURE_TREE/dist"
mkdir -p "$ROOT2/target"

ROOT1_MATCHES="$(find_vendor_matches "$ROOT1")"
ROOT2_MATCHES="$(find_vendor_matches "$ROOT2")"

# 2.3: .git is never descended into / reported.
assert_substr_not_contains \
  ".git exclusion holds (root1/.git/node_modules never reported)" \
  "$ROOT1_MATCHES" \
  "$ROOT1/.git"

# Sibling non-.git vendor dir at the same level IS reported.
assert_contains \
  "sibling non-.git vendor dir (root1/build) is reported" \
  "$ROOT1_MATCHES" \
  "$ROOT1/build"

# 2.2: prune-at-first-match - outer dist is reported, nested node_modules
# inside it is not (matched dirs are never descended into).
assert_contains \
  "outer dist is reported (prune-at-first-match)" \
  "$ROOT1_MATCHES" \
  "$ROOT1/dist"

assert_not_contains \
  "nested dist/node_modules is not reported (pruned at dist)" \
  "$ROOT1_MATCHES" \
  "$ROOT1/dist/node_modules"

# 2.4: the scanned root itself is never returned, even when its own
# basename is a vendor name.
assert_not_contains \
  "root is never returned even when its own basename is a vendor name" \
  "$ROOT2_MATCHES" \
  "$(printf '%s\n' "$ROOT2")"

assert_contains \
  "a genuine match found inside the vendor-named root is still reported" \
  "$ROOT2_MATCHES" \
  "$ROOT2/target"

echo
echo "${BOLD}Cross-check: is_vendor_dir_path agrees with find_vendor_matches${NC}"

ALL_MATCHES="$(printf '%s\n%s\n' "$ROOT1_MATCHES" "$ROOT2_MATCHES" | grep -v '^$' || true)"
CROSS_CHECK_OK=1
while IFS= read -r matched_path; do
  [[ -z "$matched_path" ]] && continue
  if ! is_vendor_dir_path "$matched_path"; then
    CROSS_CHECK_OK=0
    fail "is_vendor_dir_path agrees on every find_vendor_matches result" \
      "disagreement on: $matched_path"
  fi
done <<< "$ALL_MATCHES"
if [[ "$CROSS_CHECK_OK" -eq 1 ]]; then
  pass "is_vendor_dir_path agrees on every find_vendor_matches result"
fi

# Negative case: a real, non-vendor path must disagree (return false).
assert_false \
  "is_vendor_dir_path rejects a genuine non-vendor path" \
  is_vendor_dir_path "$ROOT1/normal/file.txt"

echo
echo "────────────────────────────────────────────────────────────────────"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "${BOLD}${GREEN}All $TOTAL assertions passed.${NC}"
  exit 0
else
  echo "${BOLD}${RED}$FAIL_COUNT of $TOTAL assertions failed.${NC}"
  exit 1
fi
