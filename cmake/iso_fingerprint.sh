#!/bin/sh
# Equivalence gate for a boot2docker ISO. Compares toolchain-INVARIANT version-facts only
# (kernel token, ISO volume label, engine label) -- NOT bytes/timestamps/build-host hash,
# which a from-source rebuild legitimately changes. Portable: strings + dd only.
#   emit    <iso> <out-dir>   : write fingerprint files
#   compare <ref-dir> <iso>   : re-emit + diff vs committed reference
set -eu
. "$(dirname "$0")/common.sh"
export LC_ALL=C

emit() {  # <iso> <out-dir>
  iso=$1; out=$2; mkdir -p "$out"
  [ -f "$iso" ] || mvd_die "missing iso $iso"
  strings "$iso" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-boot2docker' \
    | sort -u | head -1 > "$out/kernel" || true
  [ -s "$out/kernel" ] || mvd_die "no kernel token in $iso"
  # PVD volume identifier: 32 bytes at absolute offset 32808 (sector 16 + 40).
  # Capture then printf a single trailing newline: BSD sed appends a newline to
  # unterminated input while GNU sed preserves its absence, so writing sed's output
  # straight to the file made the emitted `label` platform-dependent (the Mac-emitted
  # reference had a trailing newline the Linux re-emit lacked -> spurious DIVERGENCE).
  # $() strips trailing newlines; printf re-adds exactly one, matching kernel/engine
  # (which get theirs from `head`) and the committed reference on every platform.
  label=$(dd if="$iso" bs=1 skip=32808 count=32 2>/dev/null | tr -d '\0' | sed 's/ *$//')
  [ -n "$label" ] || mvd_die "no volume label in $iso"
  printf '%s\n' "$label" > "$out/label"
  strings "$iso" 2>/dev/null | grep -oE 'b2d-v[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -u | head -1 > "$out/engine" || true
  [ -s "$out/engine" ] || mvd_die "no engine label in $iso"
}

case "${1:-}" in
  emit)    [ $# -eq 3 ] || { echo "usage: $0 emit <iso> <out-dir>" >&2; exit 64; }
           emit "$2" "$3"; echo "fingerprint written to $3" >&2 ;;
  compare) [ $# -eq 3 ] || { echo "usage: $0 compare <ref-dir> <iso>" >&2; exit 64; }
           ref=$2; iso=$3
           [ -d "$ref" ] || mvd_die "missing reference dir $ref"
           for f in kernel label engine; do [ -s "$ref/$f" ] || mvd_die "reference missing $f"; done
           tmp=$(mktemp -d "${TMPDIR:-/tmp}/mvd-isofp.XXXXXX")
           trap 'rm -rf "$tmp" "$tmp.diff"' EXIT
           emit "$iso" "$tmp"
           if diff -ru "$ref" "$tmp" > "$tmp.diff" 2>&1; then
             echo "EQUIVALENT: $iso matches reference $ref"
           else
             echo "DIVERGENCE: $iso differs from reference $ref" >&2; cat "$tmp.diff" >&2; exit 1
           fi ;;
  *) echo "usage: $0 emit|compare ..." >&2; exit 64 ;;
esac
