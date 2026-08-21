#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
APP_DIR="$DIR/Gemini Desktop.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Compiling GeminiDesktop using Swift..."
swift build -c release

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "📦 Creating Bundle Structure..."
cp "$DIR/.build/release/GeminiDesktop" "$MACOS_DIR/GeminiDesktop"
if [ -f "$DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" ]; then
    cp "$DIR/Sources/GeminiDesktop/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "$DIR/Sources/GeminiDesktop/Resources/NativeIcon.png" ]; then
    cp "$DIR/Sources/GeminiDesktop/Resources/NativeIcon.png" "$RESOURCES_DIR/NativeIcon.png"
fi

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
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
echo "✅ App bundle created successfully at: $APP_DIR"

echo "🚀 Installing to /Applications..."
# Remove existing if any
rm -rf "/Applications/Gemini Desktop.app"
cp -R "$APP_DIR" "/Applications/"
echo "✅ Gemini Desktop successfully installed in /Applications!"
echo "You can now launch it from Launchpad or Spotlight."
