#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"
PKG_SIGNING_IDENTITY="${PKG_SIGNING_IDENTITY:-}"

read_version_file() {
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "build-pkg: VERSION file not found at $VERSION_FILE" >&2
    exit 1
  fi

  local version
  version="$(tr -d '[:space:]' < "$VERSION_FILE")"
  if [[ -z "$version" ]]; then
    echo "build-pkg: VERSION file is empty" >&2
    exit 1
  fi

  printf '%s\n' "$version"
}

is_arch_value() {
  case "$1" in
    native|arm64|x86_64|intel)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

VERSION=""
ARCH="${ARCH:-native}"

if [[ $# -gt 0 ]]; then
  if is_arch_value "$1"; then
    ARCH="$1"
  else
    VERSION="$1"
    if [[ $# -gt 1 ]]; then
      ARCH="$2"
    fi
  fi
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(read_version_file)"
fi

BUILD_DIR="$ROOT_DIR/build"
STAGE_ROOT="$BUILD_DIR/pkgroot"
DIST_DIR="$ROOT_DIR/dist"
SCRIPTS_DIR="$ROOT_DIR/scripts/pkg"
SCRATCH_DIR="$BUILD_DIR/swiftpm/${ARCH}"
RELEASE_DIR="$SCRATCH_DIR/release"
PACKAGE_NAME="RemoteSudoTouchMacos-${VERSION}-${ARCH}.pkg"
PACKAGE_PATH="$DIST_DIR/$PACKAGE_NAME"

echo "== Building release binaries =="
"$ROOT_DIR/scripts/build-release.sh" "$ARCH" "$SCRATCH_DIR"

HELPER_BIN="$RELEASE_DIR/remote-sudo-touch-macos"
RSUDO_BIN="$RELEASE_DIR/rsudo"

if [[ ! -x "$HELPER_BIN" || ! -x "$RSUDO_BIN" ]]; then
  echo "build-pkg: expected release binaries were not found under $RELEASE_DIR" >&2
  exit 1
fi

rm -rf "$STAGE_ROOT" "$PACKAGE_PATH"
mkdir -p \
  "$STAGE_ROOT/usr/local/bin" \
  "$STAGE_ROOT/usr/local/libexec/remote-sudo-touch" \
  "$STAGE_ROOT/usr/local/etc/remote-sudo-touch" \
  "$DIST_DIR"

install -m 0755 "$RSUDO_BIN" "$STAGE_ROOT/usr/local/bin/rsudo"
install -m 0755 "$HELPER_BIN" "$STAGE_ROOT/usr/local/libexec/remote-sudo-touch/remote-sudo-touch-macos"
install -m 0644 "$ROOT_DIR/config/config.json" "$STAGE_ROOT/usr/local/etc/remote-sudo-touch/config.json.default"

PKGBUILD_ARGS=(
  --root "$STAGE_ROOT"
  --identifier "net.pomace.remotesudotouch.macos"
  --version "$VERSION"
  --install-location /
  --scripts "$SCRIPTS_DIR"
)

if [[ -n "$PKG_SIGNING_IDENTITY" ]]; then
  PKGBUILD_ARGS+=(--sign "$PKG_SIGNING_IDENTITY")
fi

PKGBUILD_ARGS+=("$PACKAGE_PATH")

echo "== Building installer package =="
/usr/bin/pkgbuild "${PKGBUILD_ARGS[@]}"

echo
echo "Created installer:"
echo "  $PACKAGE_PATH"
