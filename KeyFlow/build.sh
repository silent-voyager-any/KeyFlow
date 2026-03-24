#!/bin/bash
# =============================================================
#  KeyFlow — Build Script
#  C++ backend + WebView frontend (HTML/CSS)
# =============================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="KeyFlow"
APP_BUNDLE="dist/${APP_NAME}.app"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       KeyFlow — Build Script         ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Check tools ─────────────────────────────────────────────
echo "▸ Checking tools..."
if ! command -v clang++ &>/dev/null; then
  echo "✗ clang++ not found. Run: xcode-select --install"; exit 1
fi
echo "  clang++: $(clang++ --version | head -1)"

# ── Generate icon ────────────────────────────────────────────
echo ""
echo "▸ Generating icon..."
mkdir -p KeyFlow.iconset
   for s in 16 32 64 128 256 512; do
     sips -z $s $s KeyFlow_icon.png --out KeyFlow.iconset/icon_${s}x${s}.png > /dev/null
     sips -z $((s*2)) $((s*2)) KeyFlow_icon.png --out KeyFlow.iconset/icon_${s}x${s}@2x.png > /dev/null
   done
   iconutil -c icns KeyFlow.iconset -o KeyFlow.icns
   rm -rf KeyFlow.iconset

# ── Compile ──────────────────────────────────────────────────
echo ""
echo "▸ Compiling..."
mkdir -p build

clang++ \
  -std=c++17 \
  -ObjC++ \
  -O2 \
  -o build/KeyFlow \
  main.mm EngineWrapper.mm \
  -framework Cocoa \
  -framework WebKit \
  -framework Carbon \
  -framework ApplicationServices \
  -fobjc-arc \
  -mmacosx-version-min=13.0 \
  -Wno-deprecated-declarations

echo "  Compiled: build/KeyFlow"

# ── Bundle ───────────────────────────────────────────────────
echo ""
echo "▸ Building ${APP_NAME}.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp build/KeyFlow  "${APP_BUNDLE}/Contents/MacOS/KeyFlow"
cp Info.plist     "${APP_BUNDLE}/Contents/Info.plist"
cp KeyFlow.icns   "${APP_BUNDLE}/Contents/Resources/KeyFlow.icns"

# Copy the HTML/CSS frontend into Resources so the app can load it
cp index.html     "${APP_BUNDLE}/Contents/Resources/index.html"
cp styles.css     "${APP_BUNDLE}/Contents/Resources/styles.css"

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
