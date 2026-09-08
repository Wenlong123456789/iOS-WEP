#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(awk -F': ' '/^Version:/ {print $2; exit}' "$ROOT/control")"
OUT="$ROOT/release/v$VERSION"

rm -rf "$OUT"
mkdir -p "$OUT"

echo "==> Building VansonLoader deb and dylib"
rm -rf "$ROOT/packages"
make -C "$ROOT" clean package FINALPACKAGE=1 DEBUG=0

loader_deb="$(find "$ROOT/packages" -maxdepth 1 -type f -name 'com.vanson.loader*.deb' | sort | head -n 1)"
if [ -n "$loader_deb" ]; then
  cp "$loader_deb" "$OUT/com.vanson.loader_v$VERSION.deb"
fi

loader_dylib="$ROOT/.theos/obj/VansonLoader_v$VERSION.dylib"
if [ -f "$loader_dylib" ]; then
  cp "$loader_dylib" "$OUT/VansonLoader_v$VERSION.dylib"
fi

echo "Artifacts:"
find "$OUT" -maxdepth 1 -type f -print | sort
echo "Release artifacts written to $OUT"
