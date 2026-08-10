#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
DERIVED="$ROOT/.build/ReleasePackage"

echo "→ Building Release DynoIsland…"
xcodebuild \
  -project "$ROOT/DynoIsland.xcodeproj" \
  -scheme DynoIsland \
  -configuration Release \
  -derivedDataPath "$DERIVED" \
  -destination 'platform=macOS' \
  build

APP_SRC="$DERIVED/Build/Products/Release/DynoIsland.app"
mkdir -p "$DIST"
rm -rf "$DIST/DynoIsland.app"
cp -R "$APP_SRC" "$DIST/DynoIsland.app"

# Tam AppIcon.icns’i zorla yerleştir (TCC / Sistem Ayarları için).
if [[ -f "$ROOT/DynoIsland/Resources/AppIcon.icns" ]]; then
  cp -f "$ROOT/DynoIsland/Resources/AppIcon.icns" "$DIST/DynoIsland.app/Contents/Resources/AppIcon.icns"
fi

# Masaüstüne de kopyala (varsa)
if [[ -d "$HOME/Desktop" ]]; then
  rm -rf "$HOME/Desktop/DynoIsland.app"
  cp -R "$DIST/DynoIsland.app" "$HOME/Desktop/DynoIsland.app"
  echo "→ Copied to ~/Desktop/DynoIsland.app"
fi

echo "→ Packaged: $DIST/DynoIsland.app"
# İkon önbelleğini tazele
 /usr/bin/touch "$DIST/DynoIsland.app" || true
open "$DIST"
