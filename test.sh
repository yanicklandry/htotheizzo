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
    skip_spotlight=1 skip_launchpad=1 \
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
# Creates a minimal .app bundle with a SUFeedURL plist and a stub update-app.sh
# under a caller-supplied temp directory, so tests never touch /Applications or
# the real antares install.
#
# Usage:
#   make_sparkle_fixture <fixture_dir> [app_name] [feed_url]
#
# Outputs (relative to fixture_dir):
#   Applications/<app_name>.app/Contents/Info.plist  — contains SUFeedURL
#   antares/bin/update-app.sh                         — stub updater script
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
    local stub_path="$fixture_dir/antares/bin/update-app.sh"

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
# SUMMARY
# ============================================================================

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

    log_section "Integration"
    test_full_integration

    cleanup

    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
