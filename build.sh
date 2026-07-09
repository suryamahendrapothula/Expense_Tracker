#!/bin/bash

# 1. Clone the Flutter SDK repository
git clone https://github.com/flutter/flutter.git -b stable --depth 1

# 2. Add Flutter to the path
export PATH="$PATH:`pwd`/flutter/bin"

# 3. Build the Flutter Web application in release mode
flutter build web --release
