#!/bin/bash
# build-ctan.sh
# Build CTAN-compatible package for submission
#
# CTAN Requirements:
# - Top-level directory must be the package name (jsonresume/)
# - No hidden files or directories (.gitignore, .github/, .devcontainer/)
# - Should include PDF documentation (jsonresume-doc.pdf)

set -e

VERSION="${1:-1.0.0}"
PACKAGE_NAME="jsonresume"
BUILD_DIR="dist"
CTAN_DIR="$BUILD_DIR/$PACKAGE_NAME"

echo "Building CTAN package for $PACKAGE_NAME v$VERSION"

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$CTAN_DIR"

# Update version in documentation
echo "Updating version to $VERSION in documentation..."
DATE=$(date +%Y/%m/%d)
if [ -f jsonresume-doc.tex ]; then
    sed -i "s|\\\\def\\\\packageversion{.*}|\\\\def\\\\packageversion{$VERSION}|" jsonresume-doc.tex
    sed -i "s|\\\\def\\\\packagedate{.*}|\\\\def\\\\packagedate{$DATE}|" jsonresume-doc.tex
fi

# Build documentation PDF
echo "Building documentation PDF..."
if [ -f jsonresume-doc.tex ]; then
    lualatex --interaction=nonstopmode jsonresume-doc.tex || true
    lualatex --interaction=nonstopmode jsonresume-doc.tex || true
    if [ -f jsonresume-doc.pdf ]; then
        echo "Documentation PDF built successfully"
    else
        echo "Warning: Documentation PDF build failed"
    fi
    # Clean up auxiliary files
    rm -f jsonresume-doc.aux jsonresume-doc.log jsonresume-doc.out jsonresume-doc.toc
fi

# Copy package files (no hidden files!)
cp jsonresume.sty "$CTAN_DIR/"
cp jsonresume.lua "$CTAN_DIR/"
cp README.md "$CTAN_DIR/"
cp LICENSE "$CTAN_DIR/"

# Copy documentation source and PDF
if [ -f jsonresume-doc.tex ]; then
    cp jsonresume-doc.tex "$CTAN_DIR/"
fi
if [ -f jsonresume-doc.pdf ]; then
    cp jsonresume-doc.pdf "$CTAN_DIR/"
fi

# Copy example
mkdir -p "$CTAN_DIR/example"
cp example/example.tex "$CTAN_DIR/example/"
if [ -f example/example.pdf ]; then
    cp example/example.pdf "$CTAN_DIR/example/"
fi

# Verify no hidden files are included
echo "Verifying no hidden files in package..."
HIDDEN_FILES=$(find "$CTAN_DIR" -name ".*" 2>/dev/null || true)
if [ -n "$HIDDEN_FILES" ]; then
    echo "Error: Hidden files found in package:"
    echo "$HIDDEN_FILES"
    echo "Removing hidden files..."
    find "$CTAN_DIR" -name ".*" -delete
fi

# Create simple package zip (for GitHub release)
cd "$BUILD_DIR"
zip -r "$PACKAGE_NAME.zip" "$PACKAGE_NAME"
cd ..

# Create CTAN submission package
# CTAN expects a specific structure with the package in a subdirectory named after the package
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
