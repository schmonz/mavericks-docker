# mavericks-docker

Build a modern Docker CLI from source so it runs on Mac OS X 10.9.5 (Mavericks).

The build is CMake-only, in one of two modes — the target is always Mavericks; only the
build mode differs. Each mode uses its own build dir, so a synced source tree never
clobbers itself:

- **native** — building on Mavericks 10.9 itself (system clang).
- **cross** — building for Mavericks on a modern macOS host (fetches a pinned 10.9 SDK).

## Quickstart

On Mavericks:

```sh
cmake --preset native
cmake --build --preset native
ctest --preset native
```

On a modern macOS host (cross-build for 10.9):

```sh
cmake --preset cross
cmake --build --preset cross
ctest --preset cross
```

The Docker CLI lands at `build-<mode>/docker-cli/docker`. `ctest` runs the three
fail-closed gates (compat_guard, sdk_coverage, characterize) plus the unit suite. The
large docker/cli source checkout is cached once in `.srccache/` and reused across build
dirs and hosts.
