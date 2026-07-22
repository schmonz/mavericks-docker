#!/bin/sh
# Unit tests for docker-machine-common.sh helpers via PATH stubs.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
COMMON="$ROOT/payload/docker-machine-common.sh"
[ -f "$COMMON" ] || { echo "docker_common_test: common missing" >&2; exit 1; }
fail() { echo "docker_common_test: FAIL: $*" >&2; exit 1; }

setup() {
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/container-tools-common.XXXXXX")
  BIN="$WORK/bin"; mkdir -p "$BIN"
  export HOME="$WORK/home"; mkdir -p "$HOME"
  export MAVERICKS_DOCKER_STATE_DIR="$WORK/state"
  export MAVERICKS_DOCKER_LOG="$WORK/log"
  export MAVERICKS_DOCKER_FUSION_PRESENT=1
  OLDPATH=$PATH; PATH="$BIN:$PATH"
}
teardown() { PATH=$OLDPATH; rm -rf "$WORK"; }
stub_dm() { # $1 = status word the stub echoes ("" => exit 1)
  cat > "$BIN/docker-machine" <<EOF
#!/bin/sh
[ "\$1" = status ] && { [ -n "$1" ] && { echo "$1"; exit 0; }; exit 1; }
EOF
  chmod +x "$BIN/docker-machine"
}

case_status_word() {
  setup; stub_dm Running
  ( . "$COMMON"; [ "$(status_word)" = running ] ) || fail "Running -> running"
  stub_dm Stopped
  ( . "$COMMON"; [ "$(status_word)" = stopped ] ) || fail "Stopped -> stopped"
  stub_dm ""   # absent
  ( . "$COMMON"; [ "$(status_word)" = absent ] ) || fail "empty -> absent"
  ( MAVERICKS_DOCKER_FUSION_PRESENT=0; . "$COMMON"; [ "$(status_word)" = no-fusion ] ) || fail "no fusion -> no-fusion"
  teardown
}

case_creating() {
  setup; stub_dm Stopped
  mkdir -p "$MAVERICKS_DOCKER_STATE_DIR/creating.lock"   # fresh lock
  ( . "$COMMON"; [ "$(status_word)" = creating ] ) || fail "fresh lock -> creating"
  teardown
}

case_write_state() {
  setup
  ( . "$COMMON"; write_state running )
  [ "$(cat "$MAVERICKS_DOCKER_STATE_DIR/state")" = running ] || fail "write_state must write the word"
  teardown
}

case_status_word
case_creating
case_write_state
echo "docker_common_test: OK"
