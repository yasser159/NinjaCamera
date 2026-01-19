#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="${1:-com.yasser159.NinjaCamera}"
LEVEL="${2:-debug}"

echo "Streaming Simulator logs for $BUNDLE_ID (level: $LEVEL). Ctrl+C to stop."
xcrun simctl spawn booted log stream \
  --style compact \
  --level "$LEVEL" \
  --predicate "process == \"${BUNDLE_ID##*.}\" OR subsystem CONTAINS \"${BUNDLE_ID}\""
