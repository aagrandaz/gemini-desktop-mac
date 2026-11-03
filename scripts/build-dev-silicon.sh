#!/bin/bash
#  Autor: aagrandaz@gmail.com
#
set -e

# Build an isolated Apple Silicon (arm64) or Universal .app bundle for side-by-side testing
# without interrupting or overwriting the official Gemini Desktop installation.
#
# Usage:
#   ./scripts/build-dev-silicon.sh              # Builds arm64 dev bundle in ./dist/
#   ./scripts/build-dev-silicon.sh --universal  # Builds Universal (arm64 + x86_64) dev bundle
#   ./scripts/build-dev-silicon.sh --run        # Builds and launches the isolated dev bundle

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"

ARCH_MODE="arm64"
LAUNCH_AFTER_BUILD=false

for arg in "$@"; do
    case "$arg" in
        --universal)
            ARCH_MODE="universal"
            ;;
        --x86_64)
            ARCH_MODE="x86_64"
            ;;
        --run)
            LAUNCH_AFTER_BUILD=true
            ;;
    esac
done

DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Gemini Desktop Dev"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
SCRATCH_PATH="/tmp/gemini-desktop-dev-build"
SWIFTPM_FLAGS=(
    --disable-sandbox
    --scratch-path "$SCRATCH_PATH"
    --cache-path /tmp/swiftpm-cache
    --config-path /tmp/swiftpm-config
    --security-path /tmp/swiftpm-security
)

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

if [ "$ARCH_MODE" = "universal" ]; then
    echo "🔨 Compiling GeminiDesktop for Apple Silicon (arm64) and Intel (x86_64)..."
    swift build -c release --arch arm64 --arch x86_64 "${SWIFTPM_FLAGS[@]}"
    BIN_PATH="$SCRATCH_PATH/apple/Products/Release/GeminiDesktop"
    if [ ! -f "$BIN_PATH" ]; then
        BIN_PATH="$(find "$SCRATCH_PATH" -type f -path "*/Release/GeminiDesktop" ! -path "*.dSYM*" | head -n 1)"
    fi
elif [ "$ARCH_MODE" = "x86_64" ]; then
    echo "🔨 Compiling GeminiDesktop for Intel (x86_64)..."
    swift build -c release --arch x86_64 "${SWIFTPM_FLAGS[@]}"
    BIN_PATH="$(find "$SCRATCH_PATH" -type f -path "*Release*/GeminiDesktop" ! -path "*.dSYM*" | head -n 1)"
else
    echo "🔨 Compiling GeminiDesktop natively for Apple Silicon (arm64)..."
    swift build -c release --arch arm64 "${SWIFTPM_FLAGS[@]}"
    BIN_PATH="$(find "$SCRATCH_PATH" -type f -path "*Release*/GeminiDesktop" ! -path "*.dSYM*" | head -n 1)"
fi

if [ -z "$BIN_PATH" ] || [ ! -f "$BIN_PATH" ]; then
    echo "❌ Error: Compiled binary not found in $SCRATCH_PATH"
    exit 1
fi

echo "📦 Packaging isolated side-by-side bundle at: $APP_DIR"
cp "$BIN_PATH" "$MACOS_DIR/GeminiDesktop"
chmod +x "$MACOS_DIR/GeminiDesktop"

if [ -f "$ROOT_DIR/Sources/GeminiDesktop/Resources/Assets.xcassets/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Sources/GeminiDesktop/Resources/Assets.xcassets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
elif [ -f "$ROOT_DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

if [ -f "$ROOT_DIR/NativeIcon.png" ]; then
    cp "$ROOT_DIR/NativeIcon.png" "$RESOURCES_DIR/NativeIcon.png"
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
    <string>com.alexcding.geminidesktop.dev.arm64</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Gemini Desktop Dev</string>
    <key>CFBundleDisplayName</key>
    <string>Gemini Desktop Dev (Silicon)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0-dev</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
        <string>x86_64</string>
    </array>
    <key>LSEnvironment</key>
    <dict>
        <key>GEMINI_DEV_ISOLATED</key>
        <string>1</string>
    </dict>
    <key>NSCameraUsageDescription</key>
    <string>Gemini requires camera access for image inputs.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Gemini requires microphone access for voice input and Gemini Live.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc sign so macOS Apple Silicon Gatekeeper allows local execution cleanly
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "✅ Isolated bundle ready:"
echo "   • Path: $APP_DIR"
echo "   • Architecture: $(lipo -archs "$MACOS_DIR/GeminiDesktop" 2>/dev/null || file -b "$MACOS_DIR/GeminiDesktop")"
echo "   • Bundle ID: com.alexcding.geminidesktop.dev.arm64"
echo "   • Isolated UserDefaults suite: com.alexcding.geminidesktop.dev.arm64"
echo "   • Isolated WebKit DataStore UUID: D4E5F6A7-B8C9-4012-9345-6789ABCDEF01"
echo "   • Isolated Global Hotkey: Cmd+Option+Shift+G (won't conflict with official app)"

if [ "$LAUNCH_AFTER_BUILD" = true ]; then
    echo "🚀 Launching isolated instance (open -n)..."
    open -n "$APP_DIR"
fi
