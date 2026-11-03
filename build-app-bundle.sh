#!/bin/bash
#  Autor: aagrandaz@gmail.com
#
set -e

# Usage:
#   ./build-app-bundle.sh                # Builds local bundle without touching /Applications
#   ./build-app-bundle.sh --install      # Explicitly installs to /Applications

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_DIR="$DIR/Gemini Desktop.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SCRATCH_PATH="/tmp/gemini-desktop-release-build"

INSTALL_TO_APPLICATIONS=false
for arg in "$@"; do
    if [ "$arg" = "--install" ]; then
        INSTALL_TO_APPLICATIONS=true
    fi
done

echo "🔨 Compiling GeminiDesktop for Apple Silicon (arm64)..."
swift build -c release --arch arm64 \
    --disable-sandbox \
    --scratch-path "$SCRATCH_PATH" \
    --cache-path /tmp/swiftpm-cache \
    --config-path /tmp/swiftpm-config \
    --security-path /tmp/swiftpm-security

BIN_PATH="$(find "$SCRATCH_PATH" -type f -path "*Release*/GeminiDesktop" ! -path "*.dSYM*" | head -n 1)"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📦 Creating Bundle Structure..."
cp "$BIN_PATH" "$MACOS_DIR/GeminiDesktop"
if [ -f "$DIR/Sources/GeminiDesktop/Resources/Assets.xcassets/AppIcon.icns" ]; then
    cp "$DIR/Sources/GeminiDesktop/Resources/Assets.xcassets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "$DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" ]; then
    cp "$DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "$DIR/NativeIcon.png" ]; then
    cp "$DIR/NativeIcon.png" "$RESOURCES_DIR/NativeIcon.png"
fi

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleExecutable</key>
    <string>GeminiDesktop</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.alexcding.geminidesktop</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Gemini Desktop</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
        <string>x86_64</string>
    </array>
    <key>NSCameraUsageDescription</key>
    <string>Gemini requires camera access for image inputs.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Gemini requires microphone access for voice input and Gemini Live.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$MACOS_DIR/GeminiDesktop"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
echo "✅ App bundle created successfully at: $APP_DIR"

if [ "$INSTALL_TO_APPLICATIONS" = true ]; then
    echo "🚀 Installing to /Applications..."
    rm -rf "/Applications/Gemini Desktop.app"
    cp -R "$APP_DIR" "/Applications/"
    echo "✅ Gemini Desktop installed in /Applications!"
else
    echo "ℹ️ Skipping /Applications overwrite to protect your active official installation."
    echo "   (Pass --install if you want to copy to /Applications, or use ./scripts/build-dev-silicon.sh for isolated testing)"
fi
