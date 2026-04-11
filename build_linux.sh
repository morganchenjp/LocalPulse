#!/bin/bash
# LocalPulse Linux Build Script
# Prerequisites: flutter, clang, cmake, ninja-build, pkg-config, libgtk-3-dev
set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "[1/4] Checking Flutter..."
flutter --version

echo "[2/4] Getting dependencies..."
flutter pub get

echo "[3/4] Building Linux release..."
flutter build linux --release

echo "[4/4] Packaging tar.gz..."

# Create launcher script in bundle
cat > build/linux/x64/release/bundle/localpulse.sh << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"
exec "$SCRIPT_DIR/local_pulse" "$@"
LAUNCHER
chmod +x build/linux/x64/release/bundle/localpulse.sh

mkdir -p dist
cd build/linux/x64/release
tar czf "$SCRIPT_DIR/dist/LocalPulse-${VERSION}-linux-x64.tar.gz" \
  --transform='s|^bundle|LocalPulse|' \
  bundle/

echo ""
echo "========================================"
echo "  BUILD COMPLETE"
echo "  Output: dist/LocalPulse-${VERSION}-linux-x64.tar.gz"
echo "========================================"
echo ""
echo "To run:"
echo "  tar xzf dist/LocalPulse-${VERSION}-linux-x64.tar.gz"
echo "  cd LocalPulse && ./localpulse.sh