#!/bin/bash
set -euo pipefail

# Builds AppIcon.icns from icon.svg using rsvg-convert + iconutil.
# Generates all required macOS icon sizes (16-1024 + @2x variants).

cd "$(dirname "$0")"

SVG_SOURCE="icon.svg"
ICONSET_DIR="build/AppIcon.iconset"
ICNS_OUTPUT="build/AppIcon.icns"

if [ ! -f "${SVG_SOURCE}" ]; then
    echo "✗ ${SVG_SOURCE} not found"
    exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "✗ rsvg-convert is required (brew install librsvg)"
    exit 1
fi

echo "→ Generating iconset…"
rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"

# macOS .icns required sizes (with @2x variants)
declare -a sizes=(
    "16x16:16"
    "16x16@2x:32"
    "32x32:32"
    "32x32@2x:64"
    "128x128:128"
    "128x128@2x:256"
    "256x256:256"
    "256x256@2x:512"
    "512x512:512"
    "512x512@2x:1024"
)

for entry in "${sizes[@]}"; do
    name="${entry%%:*}"
    pixels="${entry##*:}"
    out="${ICONSET_DIR}/icon_${name}.png"
    rsvg-convert -w "${pixels}" -h "${pixels}" "${SVG_SOURCE}" -o "${out}"
    echo "  ✓ ${name} (${pixels}px)"
done

echo "→ Bundling .icns…"
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_OUTPUT}"

echo ""
echo "✓ Icon built: ${ICNS_OUTPUT}"
