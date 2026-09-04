#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
SDK_PATH="${AIPOWER_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
BUILD_ROOT="$PROJECT_ROOT/.build"
DIST_ROOT="$PROJECT_ROOT/dist"
APP_PATH="$DIST_ROOT/AI Power.app"
CONTENTS_PATH="$APP_PATH/Contents"
X86_BUILD="$BUILD_ROOT/release-x86_64"
ARM_BUILD="$BUILD_ROOT/release-arm64"
X86_RELEASE="$X86_BUILD/x86_64-apple-macosx/release"
ARM_RELEASE="$ARM_BUILD/arm64-apple-macosx/release"

if [[ -e "$APP_PATH" ]]; then
    print -u2 "Refusing to overwrite existing artifact: $APP_PATH"
    exit 3
fi

env SDKROOT="$SDK_PATH" \
    CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/ModuleCache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/ModuleCache" \
    swift build --scratch-path "$X86_BUILD" -c release --arch x86_64
env SDKROOT="$SDK_PATH" \
    CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/ModuleCache" \
    SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/ModuleCache" \
    swift build --scratch-path "$ARM_BUILD" -c release --arch arm64

mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS_PATH/Info.plist"
lipo -create "$X86_RELEASE/AIPower" "$ARM_RELEASE/AIPower" -output "$CONTENTS_PATH/MacOS/AI Power"
cp -R "$X86_RELEASE/AIPower_AIPower.bundle" "$CONTENTS_PATH/Resources/"

ICON_GENERATOR="$BUILD_ROOT/icon-generator"
swiftc -sdk "$SDK_PATH" -framework AppKit "$PROJECT_ROOT/Scripts/GenerateIcon.swift" -o "$ICON_GENERATOR"
ICONSET_PATH="$BUILD_ROOT/AppIcon.iconset"
mkdir -p "$ICONSET_PATH"
"$ICON_GENERATOR" "$ICONSET_PATH"
iconutil -c icns "$ICONSET_PATH" -o "$CONTENTS_PATH/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP_PATH"
plutil -lint "$CONTENTS_PATH/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ROOT/AI-Power-1.1.0-macOS.zip"
lipo -archs "$CONTENTS_PATH/MacOS/AI Power"
print "$APP_PATH"
