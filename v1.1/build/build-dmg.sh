#!/bin/bash
# Sige DMG Build Script
# Usage: bash build/build-dmg.sh
# Prerequisites: swift build -c release (binary must exist)

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
STAGING="$BUILD_DIR/staging"
DMG_OUT="$BUILD_DIR/Sige-1.1.dmg"
TMP_DMG="$BUILD_DIR/dmg_staging.dmg"

echo "=== Sige DMG Builder ==="

# 1. Ensure staging structure
mkdir -p "$STAGING/Sige.app/Contents/MacOS"
mkdir -p "$STAGING/Sige.app/Contents/Resources"

# 2. Find and copy binary
BINARY=$(find "$PROJECT_DIR/.build" -name "Sige" -type f ! -path "*.dSYM*" 2>/dev/null | head -1)
if [ -z "$BINARY" ]; then
    echo "ERROR: Sige binary not found. Run 'swift build -c release' first."
    exit 1
fi
echo "Binary: $BINARY"
cp "$BINARY" "$STAGING/Sige.app/Contents/MacOS/Sige"
chmod +x "$STAGING/Sige.app/Contents/MacOS/Sige"

# 3. Copy / update Info.plist
if [ ! -f "$STAGING/Sige.app/Contents/Info.plist" ]; then
    cat > "$STAGING/Sige.app/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Sige</string>
    <key>CFBundleIdentifier</key>
    <string>com.sige.breakreminder</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST
fi

# 4. Generate icon if not present
if [ ! -f "$STAGING/Sige.app/Contents/Resources/AppIcon.icns" ]; then
    echo "=== Generating icon ==="
    pushd "$BUILD_DIR/icon-gen" > /dev/null
    swift generate-icon.swift
    cp AppIcon.icns "$STAGING/Sige.app/Contents/Resources/AppIcon.icns"
    popd > /dev/null
fi

# 5. Create Applications symlink
rm -f "$STAGING/Applications"
ln -s /Applications "$STAGING/Applications"

# 6. Build DMG
echo "=== Building DMG ==="
rm -f "$DMG_OUT" "$TMP_DMG"
hdiutil create -srcfolder "$STAGING" -volname "Sige" -fs HFS+ -format UDRW "$TMP_DMG" -quiet
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_OUT" -quiet

# 7. Copy to product page
cp "$DMG_OUT" "$BUILD_DIR/product-page/Sige-1.1.dmg"

echo ""
echo "=== Done ==="
echo "DMG: $DMG_OUT ($(ls -lh "$DMG_OUT" | awk '{print $5}'))"
echo "SHA256: $(shasum -a 256 "$DMG_OUT" | awk '{print $1}')"
