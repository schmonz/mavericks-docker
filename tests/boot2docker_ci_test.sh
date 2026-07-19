#!/bin/sh
# boot2docker.yml exists, runs on ubuntu, drives the iso preset + ctest. When a YAML
# parser is available it must also parse cleanly; otherwise the grep checks are the gate.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W="$ROOT/.github/workflows/boot2docker.yml"
[ -f "$W" ] || { echo "missing $W" >&2; exit 1; }
# Strict parse when PyYAML is present -- a real parse error must FAIL, not be masked.
# Fall back to the grep checks below only when no parser exists (don't false-fail hosts
# lacking PyYAML).
if python3 -c "import yaml" 2>/dev/null; then
  python3 -c "import yaml; yaml.safe_load(open('$W'))" \
    || { echo "boot2docker.yml is not valid YAML" >&2; exit 1; }
else
  echo "boot2docker_ci_test: no PyYAML; relying on structural grep checks" >&2
fi
grep -q 'runs-on: ubuntu-latest' "$W" || { echo "not ubuntu-latest" >&2; exit 1; }
grep -q 'cmake --preset iso' "$W"     || { echo "missing configure preset" >&2; exit 1; }
grep -q 'cmake --build --preset iso' "$W" || { echo "missing build preset" >&2; exit 1; }
grep -q 'ctest --preset iso' "$W"     || { echo "missing test preset" >&2; exit 1; }
echo "boot2docker_ci_test: OK"
