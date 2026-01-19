#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.yasser159.NinjaCamera}"
OUT_DIR="${2:-/tmp/ninjacamera-diagnose}"
DURATION="${3:-5m}"

mkdir -p "$OUT_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$OUT_DIR/simlog-$STAMP.txt"
SHOT_FILE="$OUT_DIR/sim-$STAMP.png"

echo "Capturing screenshot..."
xcrun simctl io booted screenshot "$SHOT_FILE"

echo "Collecting logs for $BUNDLE_ID (last $DURATION)..."
xcrun simctl spawn booted log show \
  --style compact \
  --last "$DURATION" \
  --predicate "process == \"${BUNDLE_ID##*.}\" OR subsystem CONTAINS \"${BUNDLE_ID}\"" \
  > "$LOG_FILE"

echo "Saved: $SHOT_FILE"
echo "Saved: $LOG_FILE"
