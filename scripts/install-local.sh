#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/.build/release}"
PREFIX="${PREFIX:-/usr/local}"
BIN_DIR="$PREFIX/bin"
LIBEXEC_DIR="$PREFIX/libexec/remote-sudo-touch"
CONFIG_DIR="$PREFIX/etc/remote-sudo-touch"

if [[ $EUID -ne 0 ]]; then
  echo "install-local.sh: run with sudo" >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$LIBEXEC_DIR" "$CONFIG_DIR"

install -m 0755 "$BUILD_DIR/rsudo" "$BIN_DIR/rsudo"
install -m 0755 "$BUILD_DIR/remote-sudo-touch-macos" "$LIBEXEC_DIR/remote-sudo-touch-macos"

if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  install -m 0644 "$ROOT_DIR/config/config.json" "$CONFIG_DIR/config.json"
fi

cat <<MSG
Installed:
  $BIN_DIR/rsudo
  $LIBEXEC_DIR/remote-sudo-touch-macos
  $CONFIG_DIR/config.json

Test:
  rsudo --help
  sudo PAM_USER="$USER" PAM_SERVICE=sudo "$LIBEXEC_DIR/remote-sudo-touch-macos" --dry-run
MSG
