#!/usr/bin/env bash
# Usage: ./install_icon.sh /path/to/your/icon.ico
# Converts your ICO to all required macOS AppIcon PNG sizes and drops them
# into the Xcode asset catalog automatically.

set -e

ICO="${1:-}"
if [ -z "$ICO" ]; then
  echo "Usage: $0 /path/to/your/icon.ico"
  exit 1
fi

ICONSET_DIR="$(dirname "$0")/BlurIt/BlurIt/Assets.xcassets/AppIcon.appiconset"

# Convert .ico → PNG at source resolution (256 px assumed)
TMP_PNG="$(mktemp /tmp/blurit_icon_XXXXXX.png)"
sips -s format png "$ICO" --out "$TMP_PNG" >/dev/null

echo "Source PNG created: $TMP_PNG"

generate() {
  local SIZE=$1
  local OUT="$ICONSET_DIR/$2"
  sips -z "$SIZE" "$SIZE" "$TMP_PNG" --out "$OUT" >/dev/null
  echo "  → $SIZE×$SIZE  $2"
}

echo "Generating all required sizes..."
generate  16  "icon_16x16.png"
generate  32  "icon_16x16@2x.png"
generate  32  "icon_32x32.png"
generate  64  "icon_32x32@2x.png"
generate 128  "icon_128x128.png"
generate 256  "icon_128x128@2x.png"
generate 256  "icon_256x256.png"
generate 512  "icon_256x256@2x.png"
generate 512  "icon_512x512.png"
generate 1024 "icon_512x512@2x.png"

rm "$TMP_PNG"
echo "Done! Rebuild the project in Xcode to apply the new icon."
