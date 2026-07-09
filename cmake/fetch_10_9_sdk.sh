#!/bin/sh
# Fetch + cache + checksum-verify MacOSX10.9.sdk for cross-building on a modern
# host. Prints the SDK root on stdout. Never used on the 10.9 box (system SDK).
set -eu
CACHE="${MVD_SDK_CACHE:-${TMPDIR:-/tmp}/mvd-sdk-cache}"
URL="https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX10.9.sdk.tar.xz"
SHA="fcf88ce8ff0dd3248b97f4eb81c7909f2cc786725de277f4d05a2b935cc49de0"
SDK="$CACHE/MacOSX10.9.sdk"
mkdir -p "$CACHE"
if [ ! -d "$SDK" ]; then
  TARBALL="$CACHE/MacOSX10.9.sdk.tar.xz"
  [ -f "$TARBALL" ] || curl -sL --fail -o "$TARBALL" "$URL"
  echo "$SHA  $TARBALL" | shasum -a 256 -c - >&2
  tar xf "$TARBALL" -C "$CACHE"
fi
[ -d "$SDK/usr/lib" ] || { echo "SDK missing usr/lib: $SDK" >&2; exit 1; }
echo "$SDK"
