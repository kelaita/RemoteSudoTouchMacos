#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCH="${1:-${ARCH:-native}}"
SCRATCH_PATH="${2:-${SCRATCH_PATH:-}}"

cd "$ROOT_DIR"

SWIFT_ARGS=(
  build
  -c release
)

case "$ARCH" in
  native)
    ;;
  arm64)
    SWIFT_ARGS+=(--triple arm64-apple-macosx14.0)
    ;;
  x86_64|intel)
    ARCH="x86_64"
    SWIFT_ARGS+=(--triple x86_64-apple-macosx14.0)
    ;;
  *)
    echo "build-release.sh: unsupported arch '$ARCH' (use native, arm64, or x86_64)" >&2
    exit 1
    ;;
esac

if [[ -n "$SCRATCH_PATH" ]]; then
  SWIFT_ARGS+=(--scratch-path "$SCRATCH_PATH")
fi

swift "${SWIFT_ARGS[@]}"
