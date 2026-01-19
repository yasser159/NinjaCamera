#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-/tmp/ninjacamera-screens}"
mkdir -p "$OUT_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="$OUT_DIR/sim-$STAMP.png"

echo "Taking Simulator screenshot..."
xcrun simctl io booted screenshot "$OUT_FILE"
echo "Saved: $OUT_FILE"
