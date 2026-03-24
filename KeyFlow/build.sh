#!/bin/bash
# =============================================================
#  KeyFlow — Build Script
#  SwiftUI frontend + C++ engine
# =============================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="KeyFlow"
BUNDLE_ID="com.keyflow.app"
APP_BUNDLE="dist/${APP_NAME}.app"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       KeyFlow — Build Script         ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Check tools ─────────────────────────────────────────────
echo "▸ Checking tools..."
for t in clang++ swiftc python3; do
  if ! command -v $t &>/dev/null; then
    echo "✗ $t not found. Run: xcode-select --install"; exit 1
  fi
done
echo "  swiftc:  $(swiftc --version 2>&1 | head -1)"
echo "  clang++: $(clang++ --version | head -1)"

# ── Icon ────────────────────────────────────────────────────
echo ""
echo "▸ Generating icon..."
python3 make_icon.py

# ── Compile ObjC++ engine wrapper ───────────────────────────
echo ""
echo "▸ Compiling C++ engine wrapper..."
mkdir -p build

clang++ \
  -std=c++17 \
  -ObjC++ \
  -O2 \
  -c EngineWrapper.mm \
  -o build/EngineWrapper.o \
  -framework Foundation \
  -framework ApplicationServices \
  -fobjc-arc \
  -mmacosx-version-min=13.0

echo "  Done: build/EngineWrapper.o"

# ── Compile Swift UI ────────────────────────────────────────
echo ""
echo "▸ Compiling Swift UI..."
SDK=$(xcrun --sdk macosx --show-sdk-path)

swiftc \
  UI.swift \
  -import-objc-header KeyFlow-Bridging-Header.h \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -O \
  -parse-as-library \
  -module-name KeyFlow \
  -emit-object \
  -o build/UI.o

echo "  Done: build/UI.o"

# ── Link ────────────────────────────────────────────────────
echo ""
echo "▸ Linking..."

swiftc \
  build/UI.o \
  build/EngineWrapper.o \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -module-name KeyFlow \
  -o build/KeyFlow \
  -framework Cocoa \
  -framework Carbon \
  -framework ApplicationServices \
  -Xlinker -rpath -Xlinker /usr/lib/swift

echo "  Done: build/KeyFlow"

# ── Bundle ───────────────────────────────────────────────────
echo ""
echo "▸ Building ${APP_NAME}.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
cp build/KeyFlow "${APP_BUNDLE}/Contents/MacOS/KeyFlow"
cp Info.plist    "${APP_BUNDLE}/Contents/Info.plist"
cp KeyFlow.icns  "${APP_BUNDLE}/Contents/Resources/KeyFlow.icns"
chmod +x "${APP_BUNDLE}/Contents/MacOS/KeyFlow"

# ── Sign ─────────────────────────────────────────────────────
echo ""
echo "▸ Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

# ── DMG ──────────────────────────────────────────────────────
echo ""
echo "▸ Creating DMG..."
DMG_DIR="dmg_staging"
DMG_NAME="${APP_NAME}.dmg"
rm -rf "$DMG_DIR" "$DMG_NAME"
mkdir -p "$DMG_DIR"
cp -r "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_NAME" > /dev/null
rm -rf "$DMG_DIR"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║   ✓  Build complete!                 ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  → $SCRIPT_DIR/$DMG_NAME"
echo ""
echo "  1. Open ${DMG_NAME}"
echo "  2. Drag KeyFlow → Applications"
echo "  3. Right-click → Open on first launch"
echo "  4. System Settings → Privacy → Accessibility → enable KeyFlow"
echo ""
open "$SCRIPT_DIR"
