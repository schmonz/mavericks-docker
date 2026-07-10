#!/bin/sh
# Build docker-machine -> $OUT/docker-machine. It is a GOPATH/dep-era project (no
# go.mod, vendored), so build with GO111MODULE=off under a GOPATH.  Its only cgo is
# stdlib (net/crypto), so the 10.9 legacy-support shim goes in via -extldflags (not
# CGO_LDFLAGS, which only reaches packages that themselves import "C").
# Args: SRC OUT GO CC ARCH_FLAGS SDK_FLAGS LS_A GOPATH
set -eu
SRC=$1; OUT=$2; GO=$3; CC=$4; ARCH_FLAGS=$5; SDK_FLAGS=$6; LS_A=$7; GP=$8
mkdir -p "$OUT"
cd "$SRC"
EXT="$LS_A -mmacosx-version-min=10.9 $ARCH_FLAGS $SDK_FLAGS -Wl,-undefined,dynamic_lookup"
export GOPATH="$GP" GO111MODULE=off CGO_ENABLED=1 CC GOARCH=amd64
export CGO_CFLAGS="-mmacosx-version-min=10.9 $ARCH_FLAGS $SDK_FLAGS"
"$GO" build -ldflags "-linkmode=external -extldflags \"$EXT\"" -o "$OUT/docker-machine" ./cmd/docker-machine
[ -f "$OUT/docker-machine" ] || { echo "no docker-machine binary produced" >&2; exit 1; }
echo "docker-machine: $OUT/docker-machine"
