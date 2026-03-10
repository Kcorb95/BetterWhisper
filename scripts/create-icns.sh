#!/bin/bash
set -euo pipefail

INPUT="${1:?Usage: create-icns.sh <input.png> [output.icns]}"
OUTPUT="${2:-${INPUT%.png}.icns}"

TMPDIR_PATH=$(mktemp -d)
ICONSET="$TMPDIR_PATH/AppIcon.iconset"
mkdir -p "$ICONSET"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$INPUT" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
    double=$((size * 2))
    sips -z "$double" "$double" "$INPUT" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"
rm -rf "$TMPDIR_PATH"

echo "Created: $OUTPUT"
