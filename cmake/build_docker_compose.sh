#!/bin/sh
# Build docker-compose (Compose v2; a go.mod module, not vendored) -> $OUT/docker-compose.
# Module mode downloads deps into the shared module cache. Its only cgo is stdlib, so the
# 10.9 legacy-support shim goes in via -extldflags (not CGO_LDFLAGS).
# Args: SRC OUT GO CC ARCH_FLAGS SDK_FLAGS LS_A REF
set -eu
SRC=$1; OUT=$2; GO=$3; CC=$4; ARCH_FLAGS=$5; SDK_FLAGS=$6; LS_A=$7; REF=$8
mkdir -p "$OUT"
cd "$SRC"
EXT="$LS_A -mmacosx-version-min=10.9 $ARCH_FLAGS $SDK_FLAGS -Wl,-undefined,dynamic_lookup"
export CGO_ENABLED=1 CC GOARCH=amd64
export CGO_CFLAGS="-mmacosx-version-min=10.9 $ARCH_FLAGS $SDK_FLAGS"
# -X target must track the module's major-version suffix (v2 -> v5 -> ...).
MOD=$(awk '/^module /{print $2; exit}' go.mod)
"$GO" build -ldflags "-linkmode=external -extldflags \"$EXT\" -X $MOD/internal.Version=$REF" -o "$OUT/docker-compose" ./cmd
[ -f "$OUT/docker-compose" ] || { echo "no docker-compose binary produced" >&2; exit 1; }
echo "docker-compose: $OUT/docker-compose"
