#!/bin/zsh
set -euo pipefail

# ungive/mediaremote-adapter'ı derleyip Vendor/ altına yerleştirir.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="${ROOT}/Vendor/MediaRemoteAdapter"
WORKDIR="${TMPDIR:-/tmp}/dyno-mediaremote-adapter-build"

mkdir -p "${VENDOR}"
rm -rf "${WORKDIR}"
git clone --depth 1 https://github.com/ungive/mediaremote-adapter.git "${WORKDIR}"
mkdir -p "${WORKDIR}/build"
cd "${WORKDIR}/build"
cmake ..
cmake --build .

rm -rf "${VENDOR}/MediaRemoteAdapter.framework"
cp -R "${WORKDIR}/build/MediaRemoteAdapter.framework" "${VENDOR}/"
cp "${WORKDIR}/bin/mediaremote-adapter.pl" "${VENDOR}/mediaremote-adapter.pl"
cp "${WORKDIR}/LICENSE" "${VENDOR}/LICENSE"
chmod +x "${VENDOR}/mediaremote-adapter.pl"

echo "Vendor hazır: ${VENDOR}"
/usr/bin/perl "${VENDOR}/mediaremote-adapter.pl" "${VENDOR}/MediaRemoteAdapter.framework" get --no-artwork | head -c 200 || true
echo
