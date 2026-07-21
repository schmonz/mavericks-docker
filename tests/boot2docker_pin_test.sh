#!/bin/sh
# boot2docker pin is well-formed and Renovate-trackable.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
V="$ROOT/components/boot2docker/version"
S="$ROOT/components/boot2docker/golden.sha256"
[ -f "$V" ] || { echo "missing $V" >&2; exit 1; }
grep -qE '^REPO=https://github\.com/dragonflylee/boot2docker\.git$' "$V" \
  || { echo "version: bad/missing REPO" >&2; exit 1; }
grep -qE '^REF=v[0-9]+\.[0-9]+\.[0-9]+$' "$V" \
  || { echo "version: bad/missing REF" >&2; exit 1; }
# Renovate's existing manager matches components/*/version -> confirm shape it parses:
# a REPO=...git line immediately followed by a REF=... line.
awk '/^REPO=.*\.git$/{r=1;next} r&&/^REF=/{ok=1} {r=0} END{exit ok?0:1}' "$V" \
  || { echo "version: REPO line not immediately followed by REF" >&2; exit 1; }
[ -f "$S" ] || { echo "missing $S" >&2; exit 1; }
grep -qE '^[0-9a-f]{64}$' "$S" || { echo "golden.sha256 not 64 hex" >&2; exit 1; }
echo "boot2docker_pin_test: OK"
