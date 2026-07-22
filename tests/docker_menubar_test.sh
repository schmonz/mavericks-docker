#!/bin/sh
# Consistency: the menu-bar app is an LSUIElement, and the pkg installs + launches it.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail() { echo "docker_menubar_test: FAIL: $*" >&2; exit 1; }

grep -q 'LSUIElement' "$ROOT/menubar/Info.plist.in" || fail "app must be LSUIElement (agent)"
grep -q 'dev.modernmavericks.DockerMenu' "$ROOT/menubar/CMakeLists.txt" || fail "bundle id missing"

grep -q -- '--menubar-app' "$ROOT/cmake/package_pkg.sh" || fail "package_pkg.sh needs --menubar-app"
grep -q 'Applications/Container Tools for Mavericks.app' "$ROOT/cmake/package_pkg.sh" \
  || fail "package_pkg.sh must install the app to /Applications"
grep -q 'asuser' "$ROOT/cmake/package_pkg.sh" || fail "postinstall must launch the app as the console user"

grep -q -- '--menubar-app' "$ROOT/.github/workflows/release.yml" || fail "release.yml must pass --menubar-app"
grep -q 'cmake -S menubar' "$ROOT/.github/workflows/release.yml" || fail "release.yml must build the menubar app"

echo "docker_menubar_test: OK"
