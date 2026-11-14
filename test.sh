#!/usr/bin/env bash

# Comprehensive test suite for htotheizzo
# Tests actual functionality, not just existence checks

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR=""

# Run htotheizzo.sh with all package managers skipped (fast, safe for CI/tests).
# Keeps health checks, logging, and structural features active.
# Usage: run_htotheizzo_fast [extra args] > log 2>&1
run_htotheizzo_fast() {
    MOCK_MODE=1 skip_file_logging=1 \
    skip_softwareupdate=1 skip_xcode_select=1 \
    skip_disk_maintenance=1 skip_system_maintenance=1 \
    skip_spotlight="${skip_spotlight-1}" skip_launchpad=1 \
    skip_battery_check=1 \
    skip_brew=1 skip_mas=1 \
    skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
    skip_nvm=1 skip_nodenv=1 \
    skip_pip=1 skip_pip3=1 skip_pipenv=1 skip_poetry=1 skip_pdm=1 skip_uv=1 \
    skip_pyenv=1 skip_conda=1 skip_mamba=1 skip_pixi=1 \
    skip_gem=1 skip_rvm=1 skip_rbenv=1 \
    skip_rustup=1 skip_cargo=1 \
    skip_go=1 skip_goenv=1 \
    skip_composer=1 \
    skip_sdk=1 skip_jenv=1 \
    skip_docker=1 skip_podman=1 \
    skip_helm=1 skip_flutter=1 \
    skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
    skip_tfenv=1 \
    skip_gh=1 skip_gcloud=1 skip_az=1 \
    skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
    skip_sparkle=1 \
    skip_antibody=1 skip_zinit=1 skip_jenv=1 \
    skip_self_update=1 \
    skip_size_estimate=1 \
    ./htotheizzo.sh "$@"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}$*${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_test() {
    echo -e "${YELLOW}[TEST $TESTS_RUN]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

setup() {
    TEST_DIR=$(mktemp -d -t htotheizzo_test.XXXXXX)
    log "Test directory: $TEST_DIR"
}

cleanup() {
    if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Fixture factory for Sparkle-app update tests.
#
# Creates a minimal .app bundle with a SUFeedURL plist and a stub updates-apply.sh
# under a caller-supplied temp directory, so tests never touch /Applications or
# the real antares install.
#
# Usage:
#   make_sparkle_fixture <fixture_dir> [app_name] [feed_url]
#
# Outputs (relative to fixture_dir):
#   Applications/<app_name>.app/Contents/Info.plist  — contains SUFeedURL
#   antares/bin/updates-apply.sh                      — stub updater script
#   stub_args                                         — sentinel; each invocation
#                                                       of the stub appends its
#                                                       args here
#
# The stub respects two env vars the test may export before running htotheizzo:
#   STUB_SENTINEL   — path to the sentinel file (defaults to fixture_dir/stub_args)
#   STUB_EXIT_CODE  — exit code the stub should return (defaults to 0)
#
# Tests should set:
#   ANTARES_DIR="$fixture_dir/antares"
#   SPARKLE_APP_DIRS="$fixture_dir/Applications"
make_sparkle_fixture() {
    local fixture_dir="$1"
    local app_name="${2:-TestApp}"
    local feed_url="${3:-https://example.com/appcast.xml}"

    local app_contents="$fixture_dir/Applications/$app_name.app/Contents"
    local stub_path="$fixture_dir/antares/bin/updates-apply.sh"

    # Create directory structure
    mkdir -p "$app_contents"
    mkdir -p "$(dirname "$stub_path")"

    # Write SUFeedURL into the Info.plist using defaults(1) so that
    # `defaults read ... SUFeedURL` works identically to production code.
    defaults write "$app_contents/Info" SUFeedURL "$feed_url"

    # Write stub updater — records args to sentinel, honours STUB_EXIT_CODE
    cat > "$stub_path" <<'STUB'
#!/usr/bin/env bash
_sentinel="${STUB_SENTINEL:-}"
if [[ -z "$_sentinel" ]]; then
    # Derive sentinel from our own location: <fixture>/antares/bin -> <fixture>/stub_args
    _sentinel="$(cd "$(dirname "$0")/../.." && pwd)/stub_args"
fi
echo "$@" >> "$_sentinel"
exit "${STUB_EXIT_CODE:-0}"
STUB
    chmod +x "$stub_path"
}

# ============================================================================
# SKIP FLAGS TESTS
# ============================================================================

test_skip_flags() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Skip flags prevent execution"

    local output
    output=$(skip_brew=1 skip_mas=1 skip_npm=1 skip_pip=1 \
        MOCK_MODE=1 skip_file_logging=1 \
        skip_softwareupdate=1 skip_disk_maintenance=1 skip_system_maintenance=1 \
        skip_spotlight=1 skip_launchpad=1 skip_xcode_select=1 \
        skip_battery_check=1 \
        ./htotheizzo.sh 2>&1 || true)

    # Use || true: grep -c exits 1 on zero matches but still prints "0"
    local skipped_brew; skipped_brew=$(echo "$output" | grep -c "Skipped brew" || true)
    local skipped_mas;  skipped_mas=$(echo "$output"  | grep -c "Skipped mas"  || true)
    local skipped_npm;  skipped_npm=$(echo "$output"  | grep -c "Skipped npm"  || true)

    if [[ $skipped_brew -ge 1 ]] && [[ $skipped_mas -ge 1 ]] && [[ $skipped_npm -ge 1 ]]; then
        log_pass "Skip flags working correctly"
    else
        log_fail "Skip flags not working (brew:$skipped_brew mas:$skipped_mas npm:$skipped_npm)"
    fi
}

# ============================================================================
# MOCK MODE TESTS
# ============================================================================

test_mock_mode() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Mock mode executes without errors"

    local test_log="$TEST_DIR/mock_output.log"

    if run_htotheizzo_fast > "$test_log" 2>&1; then
        log_pass "Mock mode completed successfully"
    else
        log_fail "Mock mode failed with exit code $?"
    fi
}

test_health_checks() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Health checks run in mock mode"

    local test_log="$TEST_DIR/health_output.log"
    run_htotheizzo_fast > "$test_log" 2>&1

    local has_disk;    has_disk=$(grep -c "Checking disk space" "$test_log" || true)
    local has_network; has_network=$(grep -c "Checking network connectivity" "$test_log" || true)

    if [[ $has_disk -ge 1 ]] && [[ $has_network -ge 1 ]]; then
        log_pass "All health checks executed"
    else
        log_fail "Missing health checks (disk:$has_disk network:$has_network)"
    fi
}

test_error_tracking() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Error tracking and summary"

    local test_log="$TEST_DIR/error_output.log"
    run_htotheizzo_fast > "$test_log" 2>&1

    if grep -qi "updates completed" "$test_log"; then
        log_pass "Error summary displayed"
    else
        log_fail "No error summary found"
    fi
}

# ============================================================================
# CACHE CLEANUP TESTS
# ============================================================================

test_cache_find_pattern() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Cache cleanup finds all target files"

    local cache="$TEST_DIR/cache"
    mkdir -p "$cache"/{app1,app2}/{sub1,sub2}

    # Create test files
    touch "$cache/file.tmp"
    touch "$cache/file.cache"
    touch "$cache/file.log"
    touch "$cache/app1/nested.tmp"
    touch "$cache/app1/sub1/deep.cache"
    touch "$cache/app2/sub2/file.log"
    touch "$cache/keep.txt"
    touch "$cache/keep.dat"

    local found=$(find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l | tr -d ' ')

    if [[ $found -eq 6 ]]; then
        log_pass "Found all 6 target files"
    else
        log_fail "Found $found files, expected 6"
    fi
}

test_cache_deletion() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Cache cleanup deletes only target files"

    local cache="$TEST_DIR/cache_del"
    mkdir -p "$cache"

    touch "$cache/delete.tmp"
    touch "$cache/delete.cache"
    touch "$cache/delete.log"
    touch "$cache/keep.txt"
    touch "$cache/keep.json"

    find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null

    local remaining=$(find "$cache" -type f | wc -l | tr -d ' ')

    if [[ $remaining -eq 2 ]] && [[ -f "$cache/keep.txt" ]] && [[ -f "$cache/keep.json" ]]; then
        log_pass "Deleted 3 files, kept 2 safe files"
    else
        log_fail "Expected 2 files, found $remaining"
    fi
}

test_cache_performance() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Cache cleanup performance"

    local cache="$TEST_DIR/cache_perf"
    mkdir -p "$cache"/{dir1..20}/{sub1..5}

    for dir in "$cache"/*/; do
        for subdir in "$dir"/*/; do
            touch "$subdir/f.tmp" "$subdir/f.cache" "$subdir/f.log"
        done
    done

    local start=$(date +%s)
    find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null
    local end=$(date +%s)
    local duration=$((end - start))

    local remaining=$(find "$cache" -type f | wc -l | tr -d ' ')

    if [[ $remaining -eq 0 ]] && [[ $duration -lt 5 ]]; then
        log_pass "Processed 300 files in ${duration}s"
    else
        log_fail "Took ${duration}s, ${remaining} files remaining"
    fi
}

test_timeout_functionality() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Timeout mechanism works"

    if ! command -v gtimeout >/dev/null 2>&1 && ! command -v timeout >/dev/null 2>&1; then
        log "Skipping timeout test (no timeout command available)"
        return
    fi

    local timeout_cmd="timeout"
    command -v gtimeout >/dev/null 2>&1 && timeout_cmd="gtimeout"

    local script="$TEST_DIR/slow.sh"
    echo '#!/bin/bash' > "$script"
    echo 'sleep 10' >> "$script"
    chmod +x "$script"

    local start=$(date +%s)
    $timeout_cmd 2 "$script" 2>/dev/null || true
    local end=$(date +%s)
    local duration=$((end - start))

    if [[ $duration -le 3 ]]; then
        log_pass "Timeout killed process after ${duration}s"
    else
        log_fail "Timeout took ${duration}s (expected ~2s)"
    fi
}

test_empty_directory() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Handles empty directories"

    local cache="$TEST_DIR/empty"
    mkdir -p "$cache"

    local output
    output=$(find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>&1 || echo "error")

    if [[ "$output" != *"error"* ]]; then
        log_pass "Empty directory handled correctly"
    else
        log_fail "Error with empty directory"
    fi
}

test_permissions() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Handles permission errors gracefully"

    local cache="$TEST_DIR/perms"
    mkdir -p "$cache/ro"
    touch "$cache/ro/file.tmp"
    chmod 000 "$cache/ro"

    local exit_code=0
    find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || exit_code=$?

    chmod 755 "$cache/ro"

    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
        log_pass "Permission errors handled gracefully"
    else
        log_fail "Unexpected exit code: $exit_code"
    fi
}

# Load _run_cleanup and _path_size from htotheizzo.sh with a log() that
# records into $CLEANUP_LOG (issue #28).
load_cleanup_helpers() {
    CLEANUP_LOG="$TEST_DIR/cleanup.log"
    : > "$CLEANUP_LOG"
    SUITE_LOG_FN=$(declare -f log)
    log() { echo "$1" >> "$CLEANUP_LOG"; }
    eval "$(sed -n '/^_path_size() {/,/^}/p; /^_run_cleanup() {/,/^}/p' htotheizzo.sh)"
}

# Put the suite's own log() back after a helper test
restore_suite_log() {
    eval "$SUITE_LOG_FN"
}

test_run_cleanup_outcomes() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "_run_cleanup tells timeouts, protected folders and real errors apart"

    load_cleanup_helpers
    local dir="$TEST_DIR/run_cleanup"
    mkdir -p "$dir/locked" "$dir/open"
    touch "$dir/open/a.tmp" "$dir/locked/b.tmp"
    chmod 000 "$dir/locked"

    local fails=""
    _run_cleanup "Perm case" 10 find "$dir" -name "*.tmp" -type f -delete
    grep -q "^Warning:" "$CLEANUP_LOG" && fails+=" perm-case-warned"
    grep -q "Perm case: skipped 1 protected item(s).*(locked...)" "$CLEANUP_LOG" || fails+=" perm-case-not-reported"
    [[ -f "$dir/open/a.tmp" ]] && fails+=" readable-file-not-deleted"
    chmod 755 "$dir/locked"

    : > "$CLEANUP_LOG"
    _run_cleanup "Slow case" 1 sleep 5
    grep -q "^Warning: Slow case timed out after 1s$" "$CLEANUP_LOG" || fails+=" timeout-not-reported"

    : > "$CLEANUP_LOG"
    _run_cleanup "Error case" 10 sh -c 'echo "disk on fire" >&2; exit 3'
    grep -q "^Warning: Error case failed (exit 3): disk on fire$" "$CLEANUP_LOG" || fails+=" error-not-reported"

    : > "$CLEANUP_LOG"
    _run_cleanup "Clean case" 10 true
    [[ -s "$CLEANUP_LOG" ]] && fails+=" success-logged-something"
    restore_suite_log

    if [[ -z "$fails" ]]; then
        log_pass "Each outcome logged correctly"
    else
        log_fail "Wrong reporting:$fails ($(tr '\n' '|' < "$CLEANUP_LOG"))"
    fi
}

test_path_size_partial() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "_path_size keeps du's total when a subfolder is unreadable"

    load_cleanup_helpers
    local dir="$TEST_DIR/size_partial"
    mkdir -p "$dir/locked"
    head -c 20000 /dev/zero > "$dir/data.bin"
    chmod 000 "$dir/locked"
    local size
    size=$(_path_size "$dir")
    chmod 755 "$dir/locked"
    restore_suite_log

    if [[ "$size" =~ ^[0-9.,]+[BKMGTP]$ ]]; then
        log_pass "Reported size: $size"
    else
        log_fail "Got '$size'"
    fi
}

# ============================================================================
# CLI FLAGS TESTS
# ============================================================================

test_help_flag() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Help flag displays usage"

    # Capture all output first to avoid SIGPIPE from grep -q exiting early
    local output
    output=$(./htotheizzo.sh --help 2>&1)
    if echo "$output" | grep -q "comprehensive system update"; then
        log_pass "Help text displays correctly"
    else
        log_fail "Help text missing or incorrect"
    fi
}

test_dry_run_flag() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Dry-run/mock flag works"

    # Capture all output first to avoid SIGPIPE from head -20 exiting early
    local output
    output=$(skip_file_logging=1 skip_softwareupdate=1 skip_disk_maintenance=1 \
        skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 skip_xcode_select=1 \
        ./htotheizzo.sh --mock 2>&1)

    if echo "$output" | grep -q "MOCK mode"; then
        log_pass "Mock mode flag works"
    else
        log_fail "Mock mode flag not working"
    fi
}

# ============================================================================
# INTEGRATION TEST
# ============================================================================

test_full_integration() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Full integration: cache cleanup end-to-end"

    local cache="$TEST_DIR/integration"
    mkdir -p "$cache"/{app1,app2,app3}/{sub1,sub2}

    for dir in "$cache"/*; do
        for subdir in "$dir"/*; do
            touch "$subdir/temp.tmp"
            touch "$subdir/data.cache"
            touch "$subdir/debug.log"
            touch "$subdir/keep.dat"
            touch "$subdir/keep.json"
        done
    done

    local before=$(find "$cache" -type f | wc -l | tr -d ' ')
    local target=$(find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l | tr -d ' ')
    local safe=$(find "$cache" \( -name "*.dat" -o -name "*.json" \) -type f | wc -l | tr -d ' ')

    # Cleanup
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout 10 find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || true
    elif command -v timeout >/dev/null 2>&1; then
        timeout 10 find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || true
    else
        find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || true
    fi

    local after=$(find "$cache" -type f | wc -l | tr -d ' ')
    local remaining_target=$(find "$cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l | tr -d ' ')

    if [[ $remaining_target -eq 0 ]] && [[ $after -eq $safe ]]; then
        log_pass "Integration test: deleted $target files, kept $safe files"
    else
        log_fail "Integration failed: $remaining_target target files remaining"
    fi
}

# ============================================================================
# SPARKLE APP UPDATES TESTS
# ============================================================================

test_sparkle_skip_flag() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "skip_sparkle=1 bypasses Sparkle section"

    local fixture_dir; fixture_dir=$(mktemp -d)
    make_sparkle_fixture "$fixture_dir" "TestApp" "https://example.com/appcast.xml"
    local sentinel="$fixture_dir/stub_args"

    local output
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             SPARKLE_APP_DIRS="$fixture_dir/Applications" \
             STUB_SENTINEL="$sentinel" \
             skip_sparkle=1 MOCK_MODE=1 skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    local skipped; skipped=$(echo "$output" | grep -c "Skipped sparkle" || true)
    local stub_invoked=0; [[ -f "$sentinel" ]] && stub_invoked=1

    rm -rf "$fixture_dir"

    if [[ $skipped -ge 1 && $stub_invoked -eq 0 ]]; then
        log_pass "skip_sparkle bypasses section and never invokes updater"
    else
        log_fail "skip_sparkle failed (skipped:$skipped stub_invoked:$stub_invoked)"
    fi
}

test_sparkle_missing_antares() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Missing antares updater skips cleanly without warning"

    local empty_dir; empty_dir=$(mktemp -d)
    local output
    output=$(ANTARES_DIR="$empty_dir" \
             MOCK_MODE=1 skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    rm -rf "$empty_dir"

    local has_progress; has_progress=$(echo "$output" | grep -c "Updating Sparkle apps" || true)
    local has_skip; has_skip=$(echo "$output" | grep -c "Antares updater not found" || true)
    local has_warning; has_warning=$(echo "$output" | grep -c "Warning:.*[Ss]parkle" || true)

    if [[ $has_progress -ge 1 && $has_skip -ge 1 && $has_warning -eq 0 ]]; then
        log_pass "Missing antares skips cleanly with no warning"
    else
        log_fail "Missing antares handling failed (progress:$has_progress skip:$has_skip warning:$has_warning)"
    fi
}

test_sparkle_mock_mode() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "MOCK_MODE never invokes the Sparkle updater"

    local fixture_dir; fixture_dir=$(mktemp -d)
    make_sparkle_fixture "$fixture_dir" "MockApp" "https://example.com/appcast.xml"
    local sentinel="$fixture_dir/stub_args"

    local output
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             SPARKLE_APP_DIRS="$fixture_dir/Applications" \
             STUB_SENTINEL="$sentinel" \
             MOCK_MODE=1 skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    local has_mock; has_mock=$(echo "$output" | grep -c "\[MOCK\] Would update Sparkle app" || true)
    local stub_invoked=0; [[ -f "$sentinel" ]] && stub_invoked=1

    rm -rf "$fixture_dir"

    if [[ $has_mock -ge 1 && $stub_invoked -eq 0 ]]; then
        log_pass "MOCK_MODE logs intent and never invokes stub"
    else
        log_fail "MOCK_MODE failed (mock_log:$has_mock stub_invoked:$stub_invoked)"
    fi
}

test_sparkle_delegation() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Only valid-feed apps delegated; absolute path passed to updater"

    local fixture_dir; fixture_dir=$(mktemp -d)
    make_sparkle_fixture "$fixture_dir" "GoodApp" "https://example.com/appcast.xml"
    # Add a second app with non-http feed -- should be silently skipped
    mkdir -p "$fixture_dir/Applications/BadApp.app/Contents"
    defaults write "$fixture_dir/Applications/BadApp.app/Contents/Info" SUFeedURL "file:///local/feed.xml"
    local sentinel="$fixture_dir/stub_args"

    local output
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             SPARKLE_APP_DIRS="$fixture_dir/Applications" \
             STUB_SENTINEL="$sentinel" \
             SKIP_SUDO=1 \
             skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    local invocation_count=0
    [[ -f "$sentinel" ]] && invocation_count=$(wc -l < "$sentinel" | tr -d ' ')

    local good_app_path="$fixture_dir/Applications/GoodApp.app"
    local good_invoked=0
    [[ -f "$sentinel" ]] && grep -qF "$good_app_path" "$sentinel" && good_invoked=1

    local bad_invoked=0
    [[ -f "$sentinel" ]] && grep -q "BadApp" "$sentinel" && bad_invoked=1

    rm -rf "$fixture_dir"

    if [[ $invocation_count -eq 1 && $good_invoked -eq 1 && $bad_invoked -eq 0 ]]; then
        log_pass "Stub invoked once with absolute GoodApp path; BadApp skipped"
    else
        log_fail "Delegation failed (invocations:$invocation_count good:$good_invoked bad:$bad_invoked)"
    fi
}

test_sparkle_antares_ignore() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "App in antares' updates-ignore.txt is skipped, others still update"

    local fixture_dir; fixture_dir=$(mktemp -d)
    make_sparkle_fixture "$fixture_dir" "IgnoredApp" "https://example.com/appcast.xml"
    mkdir -p "$fixture_dir/Applications/KeptApp.app/Contents"
    defaults write "$fixture_dir/Applications/KeptApp.app/Contents/Info" SUFeedURL "https://example.com/appcast.xml"
    local sentinel="$fixture_dir/stub_args"

    local antares_home="$fixture_dir/antares-home"
    mkdir -p "$antares_home"
    # Case differs from the fixture's app name on purpose: matching must be
    # case-insensitive, same as antares' own _drop_ignored.
    printf '# comment, skipped\nignoredapp\tpinned for a test\n' > "$antares_home/updates-ignore.txt"

    local output
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             ANTARES_HOME="$antares_home" \
             SPARKLE_APP_DIRS="$fixture_dir/Applications" \
             STUB_SENTINEL="$sentinel" \
             SKIP_SUDO=1 \
             skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    local invocation_count=0
    [[ -f "$sentinel" ]] && invocation_count=$(wc -l < "$sentinel" | tr -d ' ')

    local kept_invoked=0
    [[ -f "$sentinel" ]] && grep -qF "$fixture_dir/Applications/KeptApp.app" "$sentinel" && kept_invoked=1

    local ignored_invoked=0
    [[ -f "$sentinel" ]] && grep -qi "IgnoredApp" "$sentinel" && ignored_invoked=1

    local logged_skip; logged_skip=$(echo "$output" | grep -c "ignored via antares.*IgnoredApp" || true)

    rm -rf "$fixture_dir"

    if [[ $invocation_count -eq 1 && $kept_invoked -eq 1 && $ignored_invoked -eq 0 && $logged_skip -ge 1 ]]; then
        log_pass "IgnoredApp skipped (case-insensitive), KeptApp still delegated"
    else
        log_fail "Antares ignore handling failed (invocations:$invocation_count kept:$kept_invoked ignored:$ignored_invoked logged:$logged_skip)"
    fi
}

test_sparkle_no_apps_found() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Empty app dir produces 'No Sparkle apps found' log"

    local fixture_dir; fixture_dir=$(mktemp -d)
    # Create antares stub so we pass the updater-exists check
    mkdir -p "$fixture_dir/antares/bin"
    printf '#!/usr/bin/env bash\n' > "$fixture_dir/antares/bin/updates-apply.sh"
    chmod +x "$fixture_dir/antares/bin/updates-apply.sh"
    # Empty apps dir
    local apps_dir="$fixture_dir/Applications"
    mkdir -p "$apps_dir"

    local output
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             SPARKLE_APP_DIRS="$apps_dir" \
             SKIP_SUDO=1 \
             skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)

    rm -rf "$fixture_dir"

    local has_no_apps; has_no_apps=$(echo "$output" | grep -c "No Sparkle apps found" || true)

    if [[ $has_no_apps -ge 1 ]]; then
        log_pass "No Sparkle apps found log produced for empty dir"
    else
        log_fail "Expected 'No Sparkle apps found' not found in output"
    fi
}

test_sparkle_failure_tolerance() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Per-app failure logged as warning and run continues"

    local fixture_dir; fixture_dir=$(mktemp -d)
    make_sparkle_fixture "$fixture_dir" "FailApp" "https://example.com/appcast.xml"
    local sentinel="$fixture_dir/stub_args"

    local output exit_code
    output=$(ANTARES_DIR="$fixture_dir/antares" \
             SPARKLE_APP_DIRS="$fixture_dir/Applications" \
             STUB_SENTINEL="$sentinel" \
             STUB_EXIT_CODE=1 \
             SKIP_SUDO=1 \
             skip_file_logging=1 \
             skip_softwareupdate=1 skip_xcode_select=1 skip_disk_maintenance=1 \
             skip_system_maintenance=1 skip_spotlight=1 skip_launchpad=1 \
             skip_battery_check=1 skip_brew=1 skip_mas=1 \
             skip_npm=1 skip_yarn=1 skip_pnpm=1 skip_bun=1 skip_deno=1 \
             skip_nvm=1 skip_nodenv=1 skip_pip=1 skip_pip3=1 skip_pipenv=1 \
             skip_poetry=1 skip_pdm=1 skip_uv=1 skip_pyenv=1 skip_conda=1 \
             skip_mamba=1 skip_pixi=1 skip_gem=1 skip_rvm=1 skip_rbenv=1 \
             skip_rustup=1 skip_cargo=1 skip_go=1 skip_goenv=1 skip_composer=1 \
             skip_sdk=1 skip_jenv=1 skip_docker=1 skip_podman=1 skip_helm=1 \
             skip_flutter=1 skip_asdf=1 skip_mise=1 skip_proto=1 skip_pkgx=1 \
             skip_tfenv=1 skip_gh=1 skip_gcloud=1 skip_az=1 \
             skip_pod=1 skip_kav=1 skip_apm=1 skip_fisher=1 \
             skip_antibody=1 skip_zinit=1 skip_self_update=1 skip_size_estimate=1 \
             ./htotheizzo.sh 2>&1 || true)
    exit_code=$?

    rm -rf "$fixture_dir"

    local has_warning; has_warning=$(echo "$output" | grep -c "Warning: Sparkle update failed" || true)
    local has_summary; has_summary=$(echo "$output" | grep -ci "updates completed with.*warning" || true)

    if [[ $has_warning -ge 1 && $exit_code -eq 0 && $has_summary -ge 1 ]]; then
        log_pass "Failure logged as warning, run exits 0, summary shows warning count"
    else
        log_fail "Failure tolerance failed (warning:$has_warning exit:$exit_code summary:$has_summary)"
    fi
}

test_sparkle_regression() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Existing fast-path tests unaffected by Sparkle addition"

    local test_log="$TEST_DIR/regression_output.log"
    if run_htotheizzo_fast > "$test_log" 2>&1; then
        log_pass "Fast-path (with skip_sparkle=1) completes successfully"
    else
        log_fail "Fast-path regression: htotheizzo.sh exited non-zero"
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

# ============================================================================
# UNATTENDED SUDO TESTS (scoped sudoers rule, unattended-sudo spec)
# ============================================================================

# Recording stubs placed first on PATH, so these tests never reach the real
# sudo, softwareupdate, osascript, defaults or mdutil. Every call is appended
# to $STUB_CALLS.
#   sudo: rejects "-n true" (no cached credentials); accepts "-v" only when
#         STUB_ALLOW_V=1; accepts the probe "-k -n /usr/bin/true <token>" only
#         when <token> equals STUB_SUDO_TOKEN; records and accepts anything else.
#   softwareupdate --list: prints STUB_SWU_LIST.
#   defaults: prints STUB_AUTO_UPDATE, or fails when it is unset.
make_sudo_stubs() {
    STUB_BIN="$TEST_DIR/stubbin"
    STUB_CALLS="$TEST_DIR/stub_calls"
    export STUB_CALLS
    mkdir -p "$STUB_BIN" "$TEST_DIR/home"
    : > "$STUB_CALLS"
    cat > "$STUB_BIN/sudo" <<'STUB'
#!/bin/bash
echo "sudo $*" >> "$STUB_CALLS"
if [[ -n "${STUB_SUDO_EXEC:-}" ]]; then
  # Install/rollback tests: act on the temp rule file as the current user.
  # Only these subcommands are ever executed; anything else is just recorded.
  case "${1:-}" in
    -v) exit 0 ;;
    -k) [[ -z "${STUB_PROBE_FAIL:-}" && -f "$STUB_RULE_FILE" ]] && grep -qF "/usr/bin/true ${4:-none}" "$STUB_RULE_FILE"; exit $? ;;
    cp|mv|rm|cat) [[ "${*: -1}" == "$STUB_RULE_FILE"* || "${2:-}" == "$STUB_RULE_FILE"* || "${3:-}" == "$STUB_RULE_FILE"* ]] || exit 97; exec "$@" ;;
    /usr/bin/install) [[ "${*: -1}" == "$STUB_RULE_FILE" ]] || exit 97; rm -f "${*: -1}" && cp "${@: -2:1}" "${*: -1}" && chmod 0440 "${*: -1}"; exit $? ;;
    /usr/sbin/visudo) [[ -z "${STUB_VISUDO_FAIL:-}" ]]; exit $? ;;
    *) exit 0 ;;
  esac
fi
if [[ "${1:-}" == "-n" && "${2:-}" == "true" ]]; then exit 1; fi
if [[ "${1:-}" == "-v" ]]; then [[ -n "${STUB_ALLOW_V:-}" ]] && exit 0; exit 1; fi
if [[ "${1:-}" == "-k" && "${2:-}" == "-n" && "${3:-}" == "/usr/bin/true" ]]; then
  [[ -n "${STUB_SUDO_TOKEN:-}" && "${4:-}" == "$STUB_SUDO_TOKEN" ]] && exit 0
  exit 1
fi
exit 0
STUB
    cat > "$STUB_BIN/softwareupdate" <<'STUB'
#!/bin/bash
echo "softwareupdate $*" >> "$STUB_CALLS"
if [[ "${1:-}" == "--list" ]]; then printf '%b' "${STUB_SWU_LIST:-No new software available.\n}"; fi
exit 0
STUB
    cat > "$STUB_BIN/osascript" <<'STUB'
#!/bin/bash
echo "osascript $*" >> "$STUB_CALLS"
exit 0
STUB
    cat > "$STUB_BIN/defaults" <<'STUB'
#!/bin/bash
echo "defaults $*" >> "$STUB_CALLS"
if [[ -n "${STUB_AUTO_UPDATE:-}" ]]; then echo "$STUB_AUTO_UPDATE"; exit 0; fi
exit 1
STUB
    cat > "$STUB_BIN/mdutil" <<'STUB'
#!/bin/bash
echo "mdutil $*" >> "$STUB_CALLS"
exit 0
STUB
    chmod +x "$STUB_BIN"/*
}

# Load the sudoers constants and helpers from htotheizzo.sh (it runs main
# when executed, so it can't be sourced)
load_sudoers_helpers() {
    eval "$(sed -n '/^SUDOERS_ALLOWED_CMDS=(/,/^)/p; /^SUDOERS_DEFAULT_FILE=/p' htotheizzo.sh)"
    eval "$(sed -n '/^sudoers_user() {/,/^}/p; /^sudoers_rule_body() {/,/^}/p; /^sudoers_probe_token() {/,/^}/p; /^sudoers_rule_text() {/,/^}/p; /^sudoers_validate_file() {/,/^}/p; /^sudoers_probe_ok() {/,/^}/p; /^sudo_cmd_allowed() {/,/^}/p; /^_sudoers_path_guard() {/,/^}/p; /^install_sudoers() {/,/^}/p; /^uninstall_sudoers() {/,/^}/p' htotheizzo.sh)"
}

# Real (non-mock) unattended run limited to the sections the caller selects
# with only_<name>=1, with every external command that matters stubbed.
# Usage: only_x=1 [STUB_...=...] run_unattended_fast > log 2>&1
run_unattended_fast() {
    if [[ "$(PATH="$STUB_BIN:$PATH" command -v sudo)" != "$STUB_BIN/sudo" ]]; then
        echo "refusing to run: stub sudo is not first on PATH" >&2
        return 99
    fi
    PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" \
        skip_file_logging=1 skip_self_update=1 \
        ./htotheizzo.sh --unattended
}

test_sudoers_rule_text() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Sudoers rule: valid, deterministic, only safe exact commands"

    local fails=""
    (
        load_sudoers_helpers
        sudoers_rule_text > "$TEST_DIR/rule1"
        sudoers_rule_text > "$TEST_DIR/rule2"
        sudoers_validate_file "$TEST_DIR/rule1" 2>/dev/null || echo "invalid-rule" >> "$TEST_DIR/rule_fails"
        cmp -s "$TEST_DIR/rule1" "$TEST_DIR/rule2" || echo "not-deterministic" >> "$TEST_DIR/rule_fails"
        [[ $(grep -c 'NOPASSWD:' "$TEST_DIR/rule1") -eq 1 ]] || echo "not-one-rule-line" >> "$TEST_DIR/rule_fails"
        grep -q "/usr/bin/true $(sudoers_probe_token)\$" "$TEST_DIR/rule1" || echo "no-probe-entry" >> "$TEST_DIR/rule_fails"
        grep -q '/usr/sbin/purge ""' "$TEST_DIR/rule1" || echo "no-empty-args-marker" >> "$TEST_DIR/rule_fails"

        local entry
        for entry in "${SUDOERS_ALLOWED_CMDS[@]}"; do
            [[ "$entry" =~ ^/usr/(bin|sbin|libexec)/ ]] || echo "non-system-path:$entry" >> "$TEST_DIR/rule_fails"
            [[ "$entry" == *[\*\?\[\\,:=!\"]* ]] && echo "meta-char:$entry" >> "$TEST_DIR/rule_fails"
            case "${entry%% *}" in
                */sh|*/bash|*/zsh|*/env|*/osascript|*/sudo|*/su|*/xcodebuild|*/periodic|*htotheizzo*)
                    echo "forbidden:$entry" >> "$TEST_DIR/rule_fails" ;;
            esac
        done

        printf '%s\n' 'u ALL=(root) NOPASSWD: purge' > "$TEST_DIR/broken_rule"
        sudoers_validate_file "$TEST_DIR/broken_rule" 2>/dev/null && echo "broken-rule-accepted" >> "$TEST_DIR/rule_fails"

        local token_before token_after
        token_before=$(sudoers_probe_token)
        SUDOERS_ALLOWED_CMDS+=("/usr/bin/true extra")
        token_after=$(sudoers_probe_token)
        [[ "$token_before" != "$token_after" ]] || echo "token-ignores-list" >> "$TEST_DIR/rule_fails"
    )
    [[ -f "$TEST_DIR/rule_fails" ]] && fails=$(tr '\n' ' ' < "$TEST_DIR/rule_fails")

    if [[ -z "$fails" ]]; then
        log_pass "Rule passes visudo, is stable, and lists only exact system commands"
    else
        log_fail "Rule problems: $fails"
    fi
}

test_sudoers_probe() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Sudoers probe: true only for the current token, never prompts"

    make_sudo_stubs
    local result
    result=$(
        load_sudoers_helpers
        token=$(sudoers_probe_token)
        export PATH="$STUB_BIN:$PATH"
        r=""
        STUB_SUDO_TOKEN="$token" sudoers_probe_ok && r+="current-ok "
        STUB_SUDO_TOKEN="htotheizzo-probe-stale000" sudoers_probe_ok || r+="stale-rejected "
        sudoers_probe_ok || r+="none-rejected "
        echo "$r"
    )
    if [[ "$result" == "current-ok stale-rejected none-rejected " ]] \
        && grep -q '^sudo -k -n /usr/bin/true htotheizzo-probe-' "$STUB_CALLS"; then
        log_pass "Probe uses -k -n and only accepts the current token"
    else
        log_fail "Probe results: '$result' calls: $(tr '\n' '|' < "$STUB_CALLS")"
    fi
}

test_install_sudoers_guards() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "--install-sudoers: macOS only; invalid rule installs nothing"

    make_sudo_stubs
    local fails="" out rc
    out=$(load_sudoers_helpers; export PATH="$STUB_BIN:$PATH"; unset HTOTHEIZZO_TEST; OSTYPE=linux-gnu; install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 1 && "$out" == *"macOS only"* ]] || fails+=" non-macos($rc:$out)"

    out=$(
        load_sudoers_helpers
        export PATH="$STUB_BIN:$PATH"
        HTOTHEIZZO_TEST=1
        SUDOERS_FILE="$TEST_DIR/fake_sudoers"
        SUDOERS_ALLOWED_CMDS=("purge")
        install_sudoers 2>&1
    ) && rc=0 || rc=$?
    [[ $rc -eq 1 && "$out" == *"failed validation"* ]] || fails+=" invalid-not-rejected($rc)"
    [[ -s "$STUB_CALLS" ]] && fails+=" sudo-called($(tr '\n' '|' < "$STUB_CALLS"))"

    out=$(load_sudoers_helpers; export PATH="$STUB_BIN:$PATH"; unset HTOTHEIZZO_TEST; SUDOERS_FILE=/tmp/elsewhere; install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 1 && "$out" == *"refusing"* ]] || fails+=" path-override-accepted"

    if [[ -z "$fails" ]]; then
        log_pass "Install refuses non-macOS, invalid rules and foreign paths without calling sudo"
    else
        log_fail "Install guards:$fails"
    fi
}

test_install_sudoers_transaction() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "--install-sudoers: installs, replaces, rolls back; --uninstall-sudoers removes"

    make_sudo_stubs
    local rule="$TEST_DIR/sudoers.d/htotheizzo" fails="" out rc
    mkdir -p "$TEST_DIR/sudoers.d"
    run_install() {
        (
            load_sudoers_helpers
            export PATH="$STUB_BIN:$PATH" STUB_SUDO_EXEC=1 STUB_RULE_FILE="$rule"
            HTOTHEIZZO_TEST=1
            SUDOERS_FILE="$rule"
            "$@"
        )
    }
    local expected
    expected=$(load_sudoers_helpers; sudoers_rule_text)

    out=$(run_install install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 ]] || fails+=" fresh-rc=$rc($out)"
    [[ "$(cat "$rule" 2>/dev/null)" == "$expected" ]] || fails+=" fresh-content"
    [[ "$(stat -f %Lp "$rule" 2>/dev/null)" == "440" ]] || fails+=" mode"
    [[ "$out" == *"/usr/sbin/purge"* && "$out" == *"--uninstall-sudoers"* ]] || fails+=" fresh-output"

    out=$(run_install install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 && "$(cat "$rule")" == "$expected" ]] || fails+=" reinstall"
    ls "$TEST_DIR/sudoers.d" | grep -q backup && fails+=" backup-left"

    chmod 644 "$rule"; echo "# old rule" > "$rule"
    out=$(STUB_PROBE_FAIL=1 run_install install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 1 && "$out" == *"not effective"*"rolled back"* ]] || fails+=" probe-fail-rc=$rc"
    [[ "$(cat "$rule")" == "# old rule" ]] || fails+=" old-not-restored"
    ls "$TEST_DIR/sudoers.d" | grep -q backup && fails+=" backup-left-after-rollback"

    rm -f "$rule"
    out=$(STUB_VISUDO_FAIL=1 run_install install_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 1 && "$out" == *"failed validation; rolled back"* ]] || fails+=" visudo-fail-rc=$rc"
    [[ -e "$rule" ]] && fails+=" new-not-removed"

    out=$(run_install install_sudoers 2>&1) || true
    out=$(run_install uninstall_sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 && ! -e "$rule" && "$out" == *"Removed"* ]] || fails+=" uninstall"

    if [[ -z "$fails" ]]; then
        log_pass "Fresh install, reinstall, both rollbacks and uninstall behave"
    else
        log_fail "Install transaction:$fails"
    fi
}

test_sudoers_status_and_uninstall() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "--status sudo rule section and --uninstall-sudoers when absent"

    make_sudo_stubs
    local token fails="" out fake="$TEST_DIR/fake_sudoers"
    token=$(load_sudoers_helpers; sudoers_probe_token)
    rm -f "$fake"

    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" HTOTHEIZZO_TEST=1 HTOTHEIZZO_SUDOERS_FILE="$fake" ./htotheizzo.sh --status 2>&1)
    [[ "$out" == *"not installed (run --install-sudoers)"* ]] || fails+=" not-installed"

    touch "$fake"
    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" HTOTHEIZZO_TEST=1 HTOTHEIZZO_SUDOERS_FILE="$fake" ./htotheizzo.sh --status 2>&1)
    [[ "$out" == *"installed but outdated"* ]] || fails+=" outdated"

    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" STUB_SUDO_TOKEN="$token" HTOTHEIZZO_TEST=1 HTOTHEIZZO_SUDOERS_FILE="$fake" ./htotheizzo.sh --status 2>&1)
    [[ "$out" == *"active (5 commands permitted)"* ]] || fails+=" active"

    rm -f "$fake"
    local rc
    out=$(PATH="$STUB_BIN:$PATH" HTOTHEIZZO_TEST=1 HTOTHEIZZO_SUDOERS_FILE="$fake" ./htotheizzo.sh --uninstall-sudoers 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 && "$out" == *"nothing to remove"* ]] || fails+=" uninstall-absent($rc)"
    grep -q 'sudo rm' "$STUB_CALLS" && fails+=" uninstall-called-sudo"

    if [[ -z "$fails" ]]; then
        log_pass "Status shows not installed / outdated / active; uninstall is a no-op when absent"
    else
        log_fail "Status/uninstall:$fails"
    fi
}

test_sudo_call_sites_match_allowlist() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Every permitted command is called with exactly its permitted form"

    local missing="" entry bin line
    while IFS= read -r entry; do
        grep -qF "sudo $entry " htotheizzo.sh || grep -qF "sudo $entry\"" htotheizzo.sh || missing+=" [$entry]"
        # every sudo call of this binary (by name or path) must use exactly this form
        bin="${entry%% *}"
        while IFS= read -r line; do
            [[ "$line" == *"sudo $entry "* || "$line" == *"sudo $entry\""* ]] || missing+=" [other-form:${line# }]"
        done < <(grep -E "sudo +(/[a-z/]+/)?${bin##*/}( |\"|$)" htotheizzo.sh | grep -v '^ *#' || true)
    done < <(load_sudoers_helpers; printf '%s\n' "${SUDOERS_ALLOWED_CMDS[@]}")

    if [[ -z "$missing" ]]; then
        log_pass "All permitted command lines appear verbatim at their call sites"
    else
        log_fail "No matching call site for:$missing"
    fi
}

test_unattended_rule_active() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Unattended + active rule: permitted steps run, others skipped and counted"

    make_sudo_stubs
    local token out rc fails=""
    token=$(load_sudoers_helpers; sudoers_probe_token)
    out=$(only_system_maintenance=1 only_spotlight=1 STUB_SUDO_TOKEN="$token" run_unattended_fast 2>&1) && rc=0 || rc=$?

    [[ $rc -eq 0 ]] || fails+=" exit=$rc"
    [[ "$out" == *"sudo rule active (5 commands permitted)"* ]] || fails+=" no-active-log"
    local cmd
    for cmd in "/usr/libexec/locate.updatedb" "/usr/bin/dscacheutil -flushcache" "/usr/bin/killall -HUP mDNSResponder"; do
        grep -qxF "sudo -n $cmd" "$STUB_CALLS" || fails+=" not-run[$cmd]"
    done
    grep -q 'mdutil' "$STUB_CALLS" && fails+=" mdutil-reached-sudo"
    [[ "$out" == *"Skipped (needs sudo): sudo mdutil -E /"* ]] || fails+=" mdutil-not-skipped"
    [[ "$out" == *"Note: 1 step(s) needing sudo were skipped"* ]] || fails+=" wrong-count"
    [[ "$out" == *"Notification sent: htotheizzo - All updates completed successfully; 1 admin step(s) skipped"* ]] || fails+=" notification"
    grep -q 'softwareupdate --install' "$STUB_CALLS" && fails+=" os-install"

    if [[ -z "$fails" ]]; then
        log_pass "3 permitted commands ran via sudo -n; Spotlight rebuild skipped and counted"
    else
        log_fail "Active rule:$fails"
    fi
}

test_unattended_rule_inactive() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Unattended without the rule: every sudo step skipped, as before"

    make_sudo_stubs
    local out rc fails=""
    out=$(only_system_maintenance=1 run_unattended_fast 2>&1) && rc=0 || rc=$?

    [[ $rc -eq 0 ]] || fails+=" exit=$rc"
    [[ "$out" == *"no sudo credentials; steps that need sudo will be skipped"* ]] || fails+=" no-skip-log"
    grep -v -e '^sudo -n true$' -e '^sudo -k -n /usr/bin/true ' -e '^osascript ' -e '^defaults ' "$STUB_CALLS" | grep -q '^sudo' && fails+=" sudo-ran($(tr '\n' '|' < "$STUB_CALLS"))"
    [[ "$out" == *"Note: 3 step(s) needing sudo were skipped"*"--install-sudoers"* ]] || fails+=" note"

    if [[ -z "$fails" ]]; then
        log_pass "No maintenance command reached sudo; 3 skipped and counted"
    else
        log_fail "Inactive rule:$fails"
    fi
}

test_unattended_softwareupdate() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Unattended: macOS updates reported, never installed; tip only when setting is off"

    make_sudo_stubs
    local list='Software Update found the following new or updated software:\n* Label: macOS Tahoe 27.2.1-26C10\n\tTitle: macOS Tahoe 27.2.1, Version: 27.2.1, Size: 1G, Recommended: YES, Action: restart,\n* Label: Safari26.2-26.2\n\tTitle: Safari, Version: 26.2, Size: 100M, Recommended: YES,\n'
    local out rc fails=""

    out=$(only_softwareupdate=1 STUB_SWU_LIST="$list" STUB_AUTO_UPDATE=0 run_unattended_fast 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 ]] || fails+=" exit=$rc"
    grep -q 'softwareupdate --install' "$STUB_CALLS" && fails+=" installed"
    [[ "$out" == *"macOS updates pending: 2"* ]] || fails+=" no-pending-log"
    [[ "$out" == *"Notification sent: htotheizzo - All updates completed successfully; macOS updates pending"* ]] || fails+=" notification"
    [[ "$out" == *"Tip: turn on System Settings"* ]] || fails+=" no-tip-when-off"
    [[ "$out" == *"needing sudo were skipped"* ]] && fails+=" counted-as-skip"

    : > "$STUB_CALLS"
    out=$(only_softwareupdate=1 STUB_SWU_LIST="$list" STUB_AUTO_UPDATE=1 run_unattended_fast 2>&1) || true
    [[ "$out" == *"Tip: turn on"* ]] && fails+=" tip-when-on"

    : > "$STUB_CALLS"
    out=$(only_softwareupdate=1 STUB_SWU_LIST="$list" run_unattended_fast 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 ]] || fails+=" unreadable-setting-exit=$rc"
    [[ "$out" == *"Tip: turn on"* ]] && fails+=" tip-when-unknown"

    : > "$STUB_CALLS"
    out=$(only_softwareupdate=1 run_unattended_fast 2>&1) && rc=0 || rc=$?
    [[ $rc -eq 0 ]] || fails+=" zero-updates-exit=$rc"
    [[ "$out" == *"macOS updates pending"* ]] && fails+=" pending-when-none"
    [[ "$out" == *"Notification sent: htotheizzo - All updates completed successfully"$'\n'* || "$out" == *"Notification sent: htotheizzo - All updates completed successfully" ]] || fails+=" plain-notification"

    if [[ -z "$fails" ]]; then
        log_pass "Pending updates logged and notified, nothing installed, tip only when off"
    else
        log_fail "softwareupdate unattended:$fails"
    fi
}

test_spotlight_opt_in() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Spotlight rebuild runs only when requested"

    make_sudo_stubs
    local fails="" out
    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" skip_spotlight= run_htotheizzo_fast 2>&1) || true
    grep -q 'mdutil' "$STUB_CALLS" && fails+=" rebuilt-by-default"
    [[ "$out" == *"Skipped spotlight"* ]] || fails+=" no-skip-log"

    : > "$STUB_CALLS"
    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" skip_spotlight= spotlight_rebuild=1 run_htotheizzo_fast 2>&1) || true
    [[ "$out" == *"MOCK: sudo mdutil -E /"* ]] || fails+=" not-rebuilt-when-requested"
    grep -q '^sudo' "$STUB_CALLS" && fails+=" mock-reached-sudo($(tr '\n' '|' < "$STUB_CALLS"))"

    out=$(PATH="$STUB_BIN:$PATH" HOME="$TEST_DIR/home" skip_spotlight= spotlight_rebuild=0 run_htotheizzo_fast 2>&1) || true
    [[ "$out" == *"mdutil"* ]] && fails+=" rebuilt-with-0"

    if [[ -z "$fails" ]]; then
        log_pass "Default run skips the rebuild; spotlight_rebuild=1 runs it"
    else
        log_fail "Spotlight gate:$fails"
    fi
}

test_help_lists_sudoers_flags() {
    TESTS_RUN=$((TESTS_RUN + 1))
    log_test "Help lists the sudoers flags and the Spotlight opt-in"

    local output
    output=$(./htotheizzo.sh --help 2>&1)
    if [[ "$output" == *"--install-sudoers"* && "$output" == *"--uninstall-sudoers"* && "$output" == *"spotlight_rebuild=1"* ]]; then
        log_pass "Help documents --install-sudoers, --uninstall-sudoers, spotlight_rebuild"
    else
        log_fail "Help is missing sudoers flags or spotlight_rebuild"
    fi
}

run_unattended_sudo_tests() {
    log_section "Unattended sudo"
    test_sudoers_rule_text
    test_sudoers_probe
    test_install_sudoers_guards
    test_install_sudoers_transaction
    test_sudoers_status_and_uninstall
    test_sudo_call_sites_match_allowlist
    test_unattended_rule_active
    test_unattended_rule_inactive
    test_unattended_softwareupdate
    test_spotlight_opt_in
    test_help_lists_sudoers_flags
}

print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    else
        echo "Tests Failed: $TESTS_FAILED"
    fi

    local pass_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi
    echo "Pass Rate:    ${pass_rate}%"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ $TESTS_FAILED test(s) failed${NC}"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "htotheizzo Test Suite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$(dirname "$0")"
    setup

    # TEST_ONLY=sudo runs just the unattended-sudo tests (fast iteration)
    if [[ "${TEST_ONLY:-}" == "sudo" ]]; then
        run_unattended_sudo_tests
        cleanup
        print_summary && exit 0 || exit 1
    fi

    log_section "Skip Flags & CLI"
    test_skip_flags
    test_help_flag
    test_dry_run_flag

    log_section "Mock Mode & Health Checks"
    test_mock_mode
    test_health_checks
    test_error_tracking

    log_section "Cache Cleanup"
    test_cache_find_pattern
    test_cache_deletion
    test_cache_performance
    test_timeout_functionality
    test_empty_directory
    test_permissions
    test_run_cleanup_outcomes
    test_path_size_partial

    log_section "Integration"
    test_full_integration

    log_section "Sparkle App Updates"
    test_sparkle_skip_flag
    test_sparkle_missing_antares
    test_sparkle_mock_mode
    test_sparkle_delegation
    test_sparkle_antares_ignore
    test_sparkle_no_apps_found
    test_sparkle_failure_tolerance
    test_sparkle_regression

    run_unattended_sudo_tests

    cleanup

    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
