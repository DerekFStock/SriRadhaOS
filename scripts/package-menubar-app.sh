#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="SriRadhaOS.app"
APP_DIR="$ROOT_DIR/dist/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST_SOURCE="$ROOT_DIR/App/Info.plist"

cd "$ROOT_DIR"

echo "Building ResourceObserverMenuBar in release mode..."
swift build -c release --product ResourceObserverMenuBar

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/ResourceObserverMenuBar"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Expected binary not found at $BIN_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$INFO_PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
cp "$BIN_PATH" "$MACOS_DIR/ResourceObserverMenuBar"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc code signature..."
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo
echo "Built app bundle:"
echo "  $APP_DIR"
echo
echo "Launch it with:"
echo "  open \"$APP_DIR\""
