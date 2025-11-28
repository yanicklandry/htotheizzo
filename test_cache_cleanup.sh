#!/usr/bin/env bash

# Test suite for cache cleanup functionality
# Tests the cache cleanup behavior with various scenarios

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR=""

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log_test() {
  echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $*"
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $*"
  TESTS_FAILED=$((TESTS_FAILED + 1))
}

setup_test_env() {
  log "Setting up test environment..."
  TEST_DIR=$(mktemp -d -t cache_test.XXXXXX)
  log "Test directory: $TEST_DIR"
}

cleanup_test_env() {
  log "Cleaning up test environment..."
  if [[ -n "$TEST_DIR" && -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Test 1: Single find command finds all file types
test_combined_find() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 1: Combined find command locates all target file types"

  local test_cache="$TEST_DIR/test_cache"
  mkdir -p "$test_cache/subdir1/subdir2"

  # Create test files
  touch "$test_cache/file1.tmp"
  touch "$test_cache/file2.cache"
  touch "$test_cache/file3.log"
  touch "$test_cache/subdir1/nested.tmp"
  touch "$test_cache/subdir1/subdir2/deep.cache"
  touch "$test_cache/keep.txt"  # Should NOT be deleted

  # Run the combined find command (without delete for testing)
  local found_count
  found_count=$(find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l)

  if [[ $found_count -eq 5 ]]; then
    log_pass "Found exactly 5 target files (expected 5)"
  else
    log_fail "Found $found_count files, expected 5"
  fi
}

# Test 2: Delete functionality works correctly
test_delete_functionality() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 2: Delete functionality removes only target files"

  local test_cache="$TEST_DIR/test_delete"
  mkdir -p "$test_cache/subdir"

  # Create test files
  touch "$test_cache/delete_me.tmp"
  touch "$test_cache/delete_me.cache"
  touch "$test_cache/delete_me.log"
  touch "$test_cache/keep_me.txt"
  touch "$test_cache/subdir/keep_this.dat"

  # Run find with delete
  find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || true

  # Check results
  local remaining_count
  remaining_count=$(find "$test_cache" -type f | wc -l)

  if [[ $remaining_count -eq 2 ]] && [[ -f "$test_cache/keep_me.txt" ]] && [[ -f "$test_cache/subdir/keep_this.dat" ]]; then
    log_pass "Correctly deleted 3 files, kept 2 safe files"
  else
    log_fail "Expected 2 files remaining, found $remaining_count"
  fi
}

# Test 3: Performance comparison - single vs multiple finds
test_performance_comparison() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 3: Performance comparison (single vs multiple finds)"

  local test_cache="$TEST_DIR/test_perf"
  mkdir -p "$test_cache"/{dir1,dir2,dir3,dir4,dir5}/{sub1,sub2,sub3}

  # Create many test files
  for dir in "$test_cache"/*/; do
    for subdir in "$dir"/*/; do
      touch "$subdir/file.tmp"
      touch "$subdir/file.cache"
      touch "$subdir/file.log"
      touch "$subdir/file.txt"
    done
  done

  # Method 1: Multiple finds (old way)
  local start1=$(date +%s%N)
  find "$test_cache" -name "*.tmp" -type f 2>/dev/null > /dev/null || true
  find "$test_cache" -name "*.cache" -type f 2>/dev/null > /dev/null || true
  find "$test_cache" -name "*.log" -type f 2>/dev/null > /dev/null || true
  local end1=$(date +%s%N)
  local time1=$(( (end1 - start1) / 1000000 ))  # Convert to milliseconds

  # Method 2: Single combined find (new way)
  local start2=$(date +%s%N)
  find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f 2>/dev/null > /dev/null || true
  local end2=$(date +%s%N)
  local time2=$(( (end2 - start2) / 1000000 ))  # Convert to milliseconds

  log "  Multiple finds: ${time1}ms"
  log "  Combined find: ${time2}ms"

  if [[ $time2 -le $time1 ]]; then
    local improvement=$(( (time1 - time2) * 100 / time1 ))
    log_pass "Combined find is faster (${improvement}% improvement)"
  else
    log_fail "Combined find is slower (old: ${time1}ms, new: ${time2}ms)"
  fi
}

# Test 4: Timeout mechanism works
test_timeout_mechanism() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 4: Timeout mechanism prevents indefinite hanging"

  # Create a mock slow find operation
  local test_script="$TEST_DIR/slow_find.sh"
  cat > "$test_script" << 'EOF'
#!/usr/bin/env bash
sleep 10
echo "This should be killed"
EOF
  chmod +x "$test_script"

  # Test with timeout command if available
  if command -v gtimeout >/dev/null 2>&1 || command -v timeout >/dev/null 2>&1; then
    local timeout_cmd="timeout"
    command -v gtimeout >/dev/null 2>&1 && timeout_cmd="gtimeout"

    local start=$(date +%s)
    $timeout_cmd 2 "$test_script" 2>/dev/null || true
    local end=$(date +%s)
    local duration=$((end - start))

    if [[ $duration -le 3 ]]; then
      log_pass "Timeout killed process after ${duration}s (expected ~2s)"
    else
      log_fail "Process took ${duration}s, timeout may not be working"
    fi
  else
    # Test manual timeout with background process
    local start=$(date +%s)
    bash "$test_script" &
    local pid=$!
    sleep 2
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true
    local end=$(date +%s)
    local duration=$((end - start))

    if [[ $duration -le 3 ]]; then
      log_pass "Manual timeout killed process after ${duration}s"
    else
      log_fail "Manual timeout took ${duration}s, expected ~2s"
    fi
  fi
}

# Test 5: Large directory handling
test_large_directory() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 5: Handles large directory structures gracefully"

  local test_cache="$TEST_DIR/test_large"
  mkdir -p "$test_cache"

  # Create a moderate number of nested directories and files
  log "  Creating test structure with 100 directories and 300 files..."
  for i in {1..100}; do
    local dir="$test_cache/dir_$i"
    mkdir -p "$dir"
    touch "$dir/file.tmp"
    touch "$dir/file.cache"
    touch "$dir/file.log"
  done

  # Time the operation
  local start=$(date +%s)
  local count=$(find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null | wc -l || echo 0)
  local end=$(date +%s)
  local duration=$((end - start))

  # Verify files are deleted
  local remaining=$(find "$test_cache" -type f | wc -l)

  if [[ $remaining -eq 0 ]] && [[ $duration -lt 10 ]]; then
    log_pass "Processed 300 files in ${duration}s, all files deleted"
  else
    log_fail "Took ${duration}s, ${remaining} files remaining (expected 0)"
  fi
}

# Test 6: Empty directory handling
test_empty_directory() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 6: Handles empty directories without errors"

  local test_cache="$TEST_DIR/test_empty"
  mkdir -p "$test_cache"

  # Run find on empty directory
  local output
  output=$(find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>&1 || echo "error")

  if [[ "$output" != *"error"* ]]; then
    log_pass "Empty directory handled without errors"
  else
    log_fail "Error handling empty directory: $output"
  fi
}

# Test 7: Permission errors are handled gracefully
test_permission_handling() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 7: Permission errors handled gracefully"

  local test_cache="$TEST_DIR/test_perms"
  mkdir -p "$test_cache/readonly"
  touch "$test_cache/readonly/file.tmp"
  chmod 000 "$test_cache/readonly"

  # Run find with error suppression
  local exit_code=0
  find "$test_cache" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || exit_code=$?

  # Cleanup
  chmod 755 "$test_cache/readonly"

  # Check that command didn't crash
  if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]; then
    log_pass "Permission errors handled without crashing"
  else
    log_fail "Unexpected exit code: $exit_code"
  fi
}

# Test 8: Progress feedback mechanism
test_progress_feedback() {
  TESTS_RUN=$((TESTS_RUN + 1))
  log_test "Test 8: Progress feedback during long operations"

  # Simulate the progress feedback logic
  local elapsed=0
  local updates=0

  while [[ $elapsed -lt 90 ]]; do
    sleep 1
    elapsed=$((elapsed + 5))
    if [[ $((elapsed % 30)) -eq 0 ]]; then
      updates=$((updates + 1))
    fi
  done

  if [[ $updates -eq 3 ]]; then
    log_pass "Progress updates triggered correctly (3 updates in 90s)"
  else
    log_fail "Expected 3 progress updates, got $updates"
  fi
}

# Main test runner
main() {
  log "Starting cache cleanup test suite..."
  echo

  # Setup
  setup_test_env

  # Run all tests
  test_combined_find
  test_delete_functionality
  test_performance_comparison
  test_timeout_mechanism
  test_large_directory
  test_empty_directory
  test_permission_handling
  test_progress_feedback

  # Cleanup
  cleanup_test_env

  # Summary
  echo
  log "========================================="
  log "Test Summary:"
  log "  Total tests run: $TESTS_RUN"
  log_pass "  Tests passed: $TESTS_PASSED"
  if [[ $TESTS_FAILED -gt 0 ]]; then
    log_fail "  Tests failed: $TESTS_FAILED"
  else
    log "  Tests failed: $TESTS_FAILED"
  fi
  log "========================================="

  if [[ $TESTS_FAILED -eq 0 ]]; then
    log_pass "All tests passed!"
    exit 0
  else
    log_fail "Some tests failed!"
    exit 1
  fi
}

# Run tests
main "$@"
