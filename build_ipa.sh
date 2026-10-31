#!/bin/bash
# Membangun Pengingat.ipa (tanpa tanda tangan) di macOS.
# Butuh Xcode penuh terpasang (bukan hanya Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"

APP=Pengingat
OUT=build

if ! SDK="$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)"; then
  echo "SDK iPhone tidak ditemukan. Pasang Xcode dari App Store, buka sekali,"
  echo "lalu jalankan: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Payload/$APP.app"

xcrun --sdk iphoneos swiftc \
  -target arm64-apple-ios16.0 \
  -sdk "$SDK" \
  -parse-as-library \
  -O \
  -module-name "$APP" \
  Sources/*.swift \
  -o "$OUT/Payload/$APP.app/$APP"

cp Info.plist "$OUT/Payload/$APP.app/Info.plist"

(cd "$OUT" && zip -qry "$APP.ipa" Payload)

echo "Selesai: $(pwd)/$OUT/$APP.ipa (belum ditandatangani)"
