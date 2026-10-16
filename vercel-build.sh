
#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.7"
SDK_DIR="/tmp/flutter-sdk"

if [ ! -x "$SDK_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$SDK_DIR"
fi

export PATH="$SDK_DIR/bin:$PATH"

flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release
