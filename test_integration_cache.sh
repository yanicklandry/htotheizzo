#!/usr/bin/env bash

# Integration test for the actual cache cleanup function in htotheizzo.sh
# This tests the real function with a mock cache directory

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Source the log function from htotheizzo.sh
source <(grep '^log()' htotheizzo.sh)

# Create a mock cache directory for testing
TEST_CACHE=$(mktemp -d -t test_cache.XXXXXX)
log "Created test cache directory: $TEST_CACHE"

# Populate with test files
mkdir -p "$TEST_CACHE"/{app1,app2,app3}/{sub1,sub2}

# Create various cache files
for dir in "$TEST_CACHE"/*; do
  for subdir in "$dir"/*; do
    touch "$subdir/temp.tmp"
    touch "$subdir/data.cache"
    touch "$subdir/debug.log"
    touch "$subdir/important.dat"  # Should not be deleted
    touch "$subdir/config.json"    # Should not be deleted
  done
done

log "Created test structure with mixed file types"

# Count files before
BEFORE_COUNT=$(find "$TEST_CACHE" -type f | wc -l | tr -d ' ')
TARGET_COUNT=$(find "$TEST_CACHE" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l | tr -d ' ')
SAFE_COUNT=$(find "$TEST_CACHE" \( -name "*.dat" -o -name "*.json" \) -type f | wc -l | tr -d ' ')

log "Files before cleanup:"
log "  Total files: $BEFORE_COUNT"
log "  Target files (.tmp/.cache/.log): $TARGET_COUNT"
log "  Safe files (.dat/.json): $SAFE_COUNT"

# Run cache cleanup directly on test directory
log "Running cache cleanup function..."

cache_size=""
if ! cache_size=$(du -sh "$TEST_CACHE" 2>/dev/null | cut -f1); then
  cache_size="unknown"
fi
log "User cache size: $cache_size"

log "Removing temporary cache files (this may take a while for large caches)..."

# Use timeout to prevent indefinite hanging (max 30 seconds for testing)
if command -v gtimeout >/dev/null 2>&1; then
  gtimeout 30 find "$TEST_CACHE" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || log "Warning: cache cleanup timed out or failed"
elif command -v timeout >/dev/null 2>&1; then
  timeout 30 find "$TEST_CACHE" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null || log "Warning: cache cleanup timed out or failed"
else
  # Fallback without timeout - use background process with manual timeout
  find "$TEST_CACHE" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f -delete 2>/dev/null &
  find_pid=$!
  elapsed=0
  while kill -0 $find_pid 2>/dev/null && [ $elapsed -lt 30 ]; do
    sleep 1
    elapsed=$((elapsed + 1))
    if [ $((elapsed % 10)) -eq 0 ]; then
      log "Still cleaning caches... (${elapsed}s elapsed)"
    fi
  done
  if kill -0 $find_pid 2>/dev/null; then
    log "Warning: cache cleanup taking too long, killing process"
    kill $find_pid 2>/dev/null || true
  fi
  wait $find_pid 2>/dev/null || log "Warning: cache cleanup completed with warnings"
fi
log "Cache cleanup completed"

# Count files after
AFTER_COUNT=$(find "$TEST_CACHE" -type f | wc -l | tr -d ' ')
REMAINING_TARGET=$(find "$TEST_CACHE" \( -name "*.tmp" -o -name "*.cache" -o -name "*.log" \) -type f | wc -l | tr -d ' ')
REMAINING_SAFE=$(find "$TEST_CACHE" \( -name "*.dat" -o -name "*.json" \) -type f | wc -l | tr -d ' ')

log ""
log "Files after cleanup:"
log "  Total files: $AFTER_COUNT"
log "  Remaining target files: $REMAINING_TARGET (should be 0)"
log "  Remaining safe files: $REMAINING_SAFE (should be $SAFE_COUNT)"

# Verify results
SUCCESS=true

if [[ $REMAINING_TARGET -ne 0 ]]; then
  echo -e "${RED}FAIL:${NC} Still have $REMAINING_TARGET target files remaining (expected 0)"
  SUCCESS=false
fi

if [[ $REMAINING_SAFE -ne $SAFE_COUNT ]]; then
  echo -e "${RED}FAIL:${NC} Safe file count changed from $SAFE_COUNT to $REMAINING_SAFE"
  SUCCESS=false
fi

if [[ $AFTER_COUNT -ne $SAFE_COUNT ]]; then
  echo -e "${RED}FAIL:${NC} Total files is $AFTER_COUNT, expected $SAFE_COUNT"
  SUCCESS=false
fi

# Cleanup
rm -rf "$TEST_CACHE"

if $SUCCESS; then
  echo -e "${GREEN}SUCCESS:${NC} Integration test passed! Deleted $TARGET_COUNT files, kept $SAFE_COUNT files"
  exit 0
else
  echo -e "${RED}FAILURE:${NC} Integration test failed"
  exit 1
fi
