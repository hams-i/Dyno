#!/bin/zsh
set -euo pipefail

# MediaRemote Adapter kaynaklarını app bundle Resources altına kopyalar.
# Framework uygulamaya LINK edilmez; yalnızca /usr/bin/perl tarafından yüklenir.

SRC="${SRCROOT}/Vendor/MediaRemoteAdapter"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/MediaRemoteAdapter"

if [[ ! -d "${SRC}/MediaRemoteAdapter.framework" ]]; then
  echo "error: Vendor/MediaRemoteAdapter/MediaRemoteAdapter.framework bulunamadı." >&2
  echo "Scripts/bootstrap-mediaremote.sh çalıştırın." >&2
  exit 1
fi

if [[ ! -f "${SRC}/mediaremote-adapter.pl" ]]; then
  echo "error: Vendor/MediaRemoteAdapter/mediaremote-adapter.pl bulunamadı." >&2
  exit 1
fi

mkdir -p "${DST}"
rm -rf "${DST}/MediaRemoteAdapter.framework"
cp -R "${SRC}/MediaRemoteAdapter.framework" "${DST}/"
cp "${SRC}/mediaremote-adapter.pl" "${DST}/mediaremote-adapter.pl"
chmod +x "${DST}/mediaremote-adapter.pl"

echo "Copied MediaRemote Adapter → ${DST}"
