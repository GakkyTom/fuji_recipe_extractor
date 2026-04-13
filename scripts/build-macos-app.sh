#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Fuji Recipe Extractor"
APP_BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR="$ROOT_DIR/.build/macos-app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_BUNDLE_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_NAME="FujiRecipeExtractorMacApp"
EXECUTABLE_PATH="$MACOS_DIR/$EXECUTABLE_NAME"
MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache.noindex"
CLANG_CACHE_DIR="$BUILD_DIR/ClangModuleCache"
ICON_SOURCE="$ROOT_DIR/macos-app/Assets/Untitled Exports/Untitled-iOS-Default-1024x1024@1x.png"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
TARGET_ARCH="$(uname -m)"

rm -rf "$APP_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR" "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR" "$CLANG_CACHE_DIR"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.png"
fi

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.fuji.recipeextractor.macos</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

SWIFT_SOURCES=("$ROOT_DIR"/macos-app/Sources/*.swift)

SWIFT_MODULECACHE_PATH="$MODULE_CACHE_DIR" \
CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
xcrun swiftc \
  -sdk "$SDK_PATH" \
  -target "${TARGET_ARCH}-apple-macos13.0" \
  -parse-as-library \
  -O \
  -framework SwiftUI \
  -framework AppKit \
  "${SWIFT_SOURCES[@]}" \
  -o "$EXECUTABLE_PATH"

xcrun codesign --force --deep --sign - "$APP_DIR" >/dev/null

if [[ -f "$RESOURCES_DIR/AppIcon.png" ]]; then
  SWIFT_MODULECACHE_PATH="$MODULE_CACHE_DIR" \
  CLANG_MODULE_CACHE_PATH="$CLANG_CACHE_DIR" \
  xcrun swift -module-cache-path "$MODULE_CACHE_DIR" - <<EOF
import AppKit
import Foundation

let appPath = "$APP_DIR"
let iconPath = "$RESOURCES_DIR/AppIcon.png"
if let image = NSImage(contentsOfFile: iconPath) {
    NSWorkspace.shared.setIcon(image, forFile: appPath, options: [])
}
EOF
fi

echo "Built app: $APP_DIR"
