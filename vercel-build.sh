#!/bin/bash

# Exit on error
set -e

echo "=== System Info ==="
node -v
npm -v

echo "=== Downloading Flutter SDK ==="
# Clone the stable Flutter branch to a local directory with depth 1 for speed
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# Add Flutter to the path for this execution context
export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Verifying Flutter installation ==="
flutter doctor

echo "=== Enabling Flutter Web ==="
flutter config --enable-web

echo "=== Building Flutter Web Application ==="
flutter build web --release

echo "=== Build Completed Successfully ==="
