#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGETS=(
  "$ROOT_DIR/build"
  "$ROOT_DIR/dist"
)

if [[ "${1:-}" == "--all" ]]; then
  TARGETS+=(
    "$ROOT_DIR/.build"
    "$ROOT_DIR/.build.pre-rename"
    "$ROOT_DIR/.swiftpm"
  )
fi

echo "Removing generated build artifacts:"
for path in "${TARGETS[@]}"; do
  if [[ -e "$path" ]]; then
    echo "  $path"
    rm -rf "$path"
  fi
done

echo "Clean complete."
