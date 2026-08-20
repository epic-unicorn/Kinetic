#!/usr/bin/env bash
# Mirrors the F-Droid metadata build recipe for local verification.
# Usage: ./tool/fdroid_build.sh parent|kids
set -euo pipefail

APP="${1:-}"
if [[ "$APP" != "parent" && "$APP" != "kids" ]]; then
  echo "Usage: $0 parent|kids" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPECTED_FLUTTER="3.44.1"
ACTUAL="$(flutter --version --machine | python3 -c 'import sys,json; print(json.load(sys.stdin)["flutterVersion"])')"
if [[ "$ACTUAL" != "$EXPECTED_FLUTTER" ]]; then
  echo "Flutter $EXPECTED_FLUTTER required (found $ACTUAL). Pin with FVM or flutter version." >&2
  exit 1
fi

dart pub global activate melos
melos bootstrap

cd "apps/$APP"
flutter build apk --release --build-name=0.3.0 --build-number=1

echo "APK: apps/$APP/build/app/outputs/flutter-apk/app-release.apk"
