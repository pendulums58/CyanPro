#!/usr/bin/env bash
# Compare current -Wconversion warnings against saved baseline.
# New warnings → exit 1.  Removed warnings → informational only.
# Usage: ./tools/warn_diff.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASELINE="$SCRIPT_DIR/warn_baseline.txt"

if [ ! -f "$BASELINE" ]; then
  echo "ERROR: baseline file not found at $BASELINE" >&2
  echo "Run: ./tools/warn_baseline.sh > tools/warn_baseline.txt" >&2
  exit 1
fi

CURRENT=$("$SCRIPT_DIR/warn_baseline.sh")

NEW=$(comm -13 "$BASELINE" <(echo "$CURRENT"))
REMOVED=$(comm -23 "$BASELINE" <(echo "$CURRENT"))

if [ -n "$REMOVED" ]; then
  echo "=== Removed warnings (good) ==="
  echo "$REMOVED"
  echo
fi

if [ -n "$NEW" ]; then
  echo "=== NEW warnings (must fix) ==="
  echo "$NEW"
  exit 1
else
  echo "No new -Wconversion warnings."
  exit 0
fi
