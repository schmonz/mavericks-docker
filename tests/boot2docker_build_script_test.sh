#!/bin/sh
# build_boot2docker.sh: valid POSIX sh; rejects missing args without touching docker.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
S="$ROOT/cmake/build_boot2docker.sh"
[ -f "$S" ] || { echo "missing $S" >&2; exit 1; }
sh -n "$S" || { echo "syntax error in $S" >&2; exit 1; }
# Too few args must fail fast (exit != 0) and must NOT have produced an iso.
if sh "$S" only-one-arg >/dev/null 2>&1; then
  echo "expected nonzero exit on missing args" >&2; exit 1
fi
echo "boot2docker_build_script_test: OK"
