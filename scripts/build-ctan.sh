#!/bin/bash
# build-ctan.sh
# Build CTAN-compatible package for submission

set -e

VERSION="${1:-1.0.0}"
PACKAGE_NAME="jsonresume"
BUILD_DIR="dist"
CTAN_DIR="$BUILD_DIR/$PACKAGE_NAME"

echo "Building CTAN package for $PACKAGE_NAME v$VERSION"

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$CTAN_DIR"

# Copy package files
cp jsonresume.sty "$CTAN_DIR/"
cp jsonresume.lua "$CTAN_DIR/"
cp README.md "$CTAN_DIR/"
cp LICENSE "$CTAN_DIR/"

# Copy example
mkdir -p "$CTAN_DIR/example"
cp example/example.tex "$CTAN_DIR/example/"
if [ -f example/example.pdf ]; then
    cp example/example.pdf "$CTAN_DIR/example/"
fi

# Create simple package zip (for GitHub release)
cd "$BUILD_DIR"
zip -r "$PACKAGE_NAME.zip" "$PACKAGE_NAME"
cd ..

# Create CTAN submission package
# CTAN expects a specific structure with the package in a subdirectory
cd "$BUILD_DIR"
zip -r "$PACKAGE_NAME-ctan.zip" "$PACKAGE_NAME"
cd ..

echo ""
echo "=========================================="
echo "CTAN package built successfully!"
echo "=========================================="
echo ""
echo "Files created:"
echo "  - $BUILD_DIR/$PACKAGE_NAME.zip (for manual installation)"
echo "  - $BUILD_DIR/$PACKAGE_NAME-ctan.zip (for CTAN submission)"
echo ""
echo "Package contents:"
ls -la "$CTAN_DIR"
echo ""
echo "To submit to CTAN:"
echo "  1. Go to https://ctan.org/upload"
echo "  2. Upload $BUILD_DIR/$PACKAGE_NAME-ctan.zip"
echo "  3. Fill in package metadata"
echo ""
