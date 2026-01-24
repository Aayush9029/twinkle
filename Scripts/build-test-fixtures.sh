#!/bin/bash
set -e

# Build test fixtures for E2E testing
# Creates versioned .app bundles and zips them

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$ROOT_DIR/Example/TwinkleExample"
FIXTURES_DIR="$ROOT_DIR/E2ETests/Fixtures"
BUILD_DIR="$ROOT_DIR/.build/fixtures"

echo "Building test fixtures..."
echo "Root: $ROOT_DIR"
echo "Fixtures: $FIXTURES_DIR"

# Clean and create directories
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$FIXTURES_DIR"

# Function to build and package a version
build_version() {
    local VERSION="$1"
    local BUILD="$2"
    local PRERELEASE="${3:-false}"

    echo ""
    echo "=== Building v$VERSION (build $BUILD) ==="

    # Build the executable
    cd "$EXAMPLE_DIR"
    swift build -c release

    # Create .app bundle structure
    local APP_NAME="TwinkleExample"
    local APP_BUNDLE="$BUILD_DIR/$APP_NAME-v$VERSION.app"
    local CONTENTS="$APP_BUNDLE/Contents"
    local MACOS="$CONTENTS/MacOS"
    local RESOURCES="$CONTENTS/Resources"

    mkdir -p "$MACOS"
    mkdir -p "$RESOURCES"

    # Copy executable
    cp "$EXAMPLE_DIR/.build/release/$APP_NAME" "$MACOS/$APP_NAME"

    # Create Info.plist with version
    cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.aayush.TwinkleExample</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

    # Create PkgInfo
    echo -n "APPL????" > "$CONTENTS/PkgInfo"

    # Ad-hoc sign the bundle (for testing)
    codesign --force --deep --sign - "$APP_BUNDLE"

    # Verify bundle
    echo "Verifying bundle..."
    /usr/bin/codesign -dvv "$APP_BUNDLE" 2>&1 | head -5

    # Create zip
    local ZIP_NAME="TwinkleExample-v$VERSION.zip"
    cd "$BUILD_DIR"
    zip -r "$FIXTURES_DIR/$ZIP_NAME" "$(basename "$APP_BUNDLE")"

    echo "Created: $FIXTURES_DIR/$ZIP_NAME"

    # Cleanup
    rm -rf "$APP_BUNDLE"
}

# Build different versions for testing

# v1.0.0 - "Current" installed version
build_version "1.0.0" "100"

# v2.0.0 - Stable update
build_version "2.0.0" "200"

# v2.1.0-beta - Beta/prerelease update
build_version "2.1.0-beta" "210" "true"

# v3.0.0 - Major update
build_version "3.0.0" "300"

# Create an invalid/corrupted zip for error testing
echo "Creating invalid zip..."
echo "not a valid zip file" > "$FIXTURES_DIR/TwinkleExample-invalid.zip"

# Create a zip with no .app (just a file)
echo "Creating no-app zip..."
mkdir -p "$BUILD_DIR/noapp"
echo "just a text file" > "$BUILD_DIR/noapp/readme.txt"
cd "$BUILD_DIR/noapp"
zip "$FIXTURES_DIR/TwinkleExample-noapp.zip" readme.txt
rm -rf "$BUILD_DIR/noapp"

# Create a zip with multiple .app bundles
echo "Creating multi-app zip..."
mkdir -p "$BUILD_DIR/multi"
mkdir -p "$BUILD_DIR/multi/App1.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/multi/App2.app/Contents/MacOS"
echo "#!/bin/bash" > "$BUILD_DIR/multi/App1.app/Contents/MacOS/App1"
echo "#!/bin/bash" > "$BUILD_DIR/multi/App2.app/Contents/MacOS/App2"
chmod +x "$BUILD_DIR/multi/App1.app/Contents/MacOS/App1"
chmod +x "$BUILD_DIR/multi/App2.app/Contents/MacOS/App2"
cd "$BUILD_DIR/multi"
zip -r "$FIXTURES_DIR/TwinkleExample-multiapp.zip" App1.app App2.app
rm -rf "$BUILD_DIR/multi"

echo ""
echo "=== Fixtures created ==="
ls -la "$FIXTURES_DIR"
echo ""
echo "Done!"
