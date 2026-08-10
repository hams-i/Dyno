#!/bin/zsh
# DynoIsland'ı derler ve dist/ klasörüne kopyalar.
# Kullanım: ./build.sh  (dist/DynoIsland.app üretir)
set -e
cd "$(dirname "$0")"

xcodebuild \
    -project DynoIsland.xcodeproj \
    -scheme DynoIsland \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    -destination 'platform=macOS' \
    build

mkdir -p dist
rm -rf dist/DynoIsland.app
cp -R build/DerivedData/Build/Products/Release/DynoIsland.app dist/

echo "✓ dist/DynoIsland.app hazır"
