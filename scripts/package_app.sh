#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/build/Span.app"
ICONSET_DIR="$PROJECT_DIR/build/Span.iconset"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$PROJECT_DIR/.build/release/Span" "$APP_DIR/Contents/MacOS/Span"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
sips -z 16 16 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$PROJECT_DIR/Resources/SpanIcon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/SpanIcon.icns"

SIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1)"
if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "No Apple Development identity found; using an ad-hoc signature."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "$APP_DIR"
