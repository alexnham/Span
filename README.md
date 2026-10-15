# Span for macOS

Span is a native SwiftUI window manager designed for ultrawide displays. It uses macOS Accessibility APIs to move and resize application windows into reusable zones.

The app includes a custom macOS icon generated specifically for Span's ultrawide zone system.

Layouts can use full-height columns or split every column across the horizontal midpoint for up to eight zones.

Use **Edit zones** to turn the current layout into a custom one. Select any region and split it left/right or top/bottom; custom layouts are saved automatically.

Compatible neighboring zones can be merged in any direction. A merge is offered when both zones share a complete edge, keeping the final region rectangular.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer, or matching Xcode Command Line Tools
- Swift 6.1 or newer

Verify the toolchain with:

```bash
swift --version
xcode-select -p
```

## Build the native app

The packaging script compiles an optimized release, generates every macOS icon size, creates `Span.app`, and signs it with the first available Apple Development identity. If no development identity exists, it uses an ad-hoc signature.

```bash
chmod +x scripts/package_app.sh
./scripts/package_app.sh
codesign --verify --deep --strict build/Span.app
open build/Span.app
```

The finished bundle is written to `build/Span.app`.

## Install in Applications

After building:

```bash
pkill -x Span 2>/dev/null || true
sudo ditto build/Span.app /Applications/Span.app
open /Applications/Span.app
```

When updating an existing installation, keep the bundle path and signing identity stable so macOS can retain Accessibility authorization.

## Accessibility permission

On first launch, grant Span access in **System Settings → Privacy & Security → Accessibility**. Span uses that permission to resize and reposition windows from other apps.

If macOS shows Span as enabled but windows do not move, remove the old Span entry, relaunch `/Applications/Span.app`, and grant access to the newly installed bundle.

## Development

Build and run the native executable without packaging:

```bash
swift build
swift run Span
```

An earlier React interface prototype is retained in `src/`. To run it:

```bash
npm install
npm run dev
```

## Shortcuts

- `Control–Option–Left/Right`: move through zones
- `Control–Option–1…6`: jump to a zone
- `Control–Option–Return`: fill the current display
