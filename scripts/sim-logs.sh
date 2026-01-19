#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.yasser159.NinjaCamera}"
DURATION="${2:-5m}"
OUT_DIR="${3:-/tmp/ninjacamera-logs}"

mkdir -p "$OUT_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$OUT_DIR/simlog-$STAMP.txt"

echo "Collecting Simulator logs for $BUNDLE_ID (last $DURATION)..."
xcrun simctl spawn booted log show \
  --style compact \
  --last "$DURATION" \
  --predicate "process == \"${BUNDLE_ID##*.}\" OR subsystem CONTAINS \"${BUNDLE_ID}\"" \
  > "$OUT_FILE"

echo "Saved: $OUT_FILE"
