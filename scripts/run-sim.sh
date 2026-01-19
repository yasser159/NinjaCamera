#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-NinjaCamera.xcodeproj}"
SCHEME="${SCHEME:-NinjaCamera}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/NinjaCameraDerived}"
BUNDLE_ID="${BUNDLE_ID:-com.yasser159.NinjaCamera}"
RUNTIME_MATCH="${RUNTIME_MATCH:-iOS-26-2}"
DEVICE_PREFER="${DEVICE_PREFER:-iPhone}"

read -r UDID STATE < <(
  python3 - <<PY
import json, subprocess, sys
runtime_match = "${RUNTIME_MATCH}"
prefer = "${DEVICE_PREFER}"
try:
    data = json.loads(subprocess.check_output(["xcrun","simctl","list","devices","-j"]))
except Exception:
    sys.exit(1)

def pick():
    for runtime, devices in data.get("devices", {}).items():
        if runtime_match not in runtime:
            continue
        # prefer a matching device type
        for d in devices:
            if d.get("isAvailable") and prefer in d.get("name", ""):
                return d.get("udid"), d.get("state")
        for d in devices:
            if d.get("isAvailable"):
                return d.get("udid"), d.get("state")
    return None

res = pick()
if not res or not res[0]:
    sys.exit(1)
print(res[0], res[1])
PY
)

if [[ -z "${UDID:-}" ]]; then
  echo "No available simulator for runtime match: ${RUNTIME_MATCH}" >&2
  exit 1
fi

if [[ "${STATE}" != "Booted" ]]; then
  xcrun simctl boot "${UDID}" || true
fi

xcodebuild build \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -sdk iphonesimulator \
  -destination "id=${UDID}" \
  -derivedDataPath "${DERIVED_DATA}"

APP_PATH="${DERIVED_DATA}/Build/Products/Debug-iphonesimulator/${SCHEME}.app"

xcrun simctl install booted "${APP_PATH}"
xcrun simctl launch booted "${BUNDLE_ID}"
