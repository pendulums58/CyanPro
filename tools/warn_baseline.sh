#!/usr/bin/env bash
# Build ocgcore with -Wconversion and emit normalized baseline.
# Usage: ./tools/warn_baseline.sh > tools/warn_baseline.txt
set -euo pipefail

CORE_DIR="$(cd "$(dirname "$0")/.." && pwd)/ocgcore"

if [ ! -d "$CORE_DIR/builddir" ]; then
  echo "ERROR: meson builddir not found. Run:" >&2
  echo "  cd ocgcore && meson setup builddir --warnlevel=3 -Dcpp_args='-Wconversion'" >&2
  exit 1
fi

cd "$CORE_DIR"
ninja -C builddir -t clean >/dev/null 2>&1
ninja -C builddir 2>&1 \
  | grep -E 'warning:.*-Wconversion' \
  | grep -v '^lua/' \
  | sed 's|^\.\./||' \
  | grep -v '^lua/' \
  | sed 's| warning: | |; s| \[-Wconversion\]$||' \
  | sort -u
