cmake_minimum_required(VERSION 3.15)

# Single source of truth for the product version (feeds .pkg name + release tag later).
file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" MVD_VERSION LIMIT_COUNT 1)
project(mavericks_docker VERSION ${MVD_VERSION} LANGUAGES NONE)
# LANGUAGES NONE: nothing is compiled natively. The real 10.9/x86_64 enforcement is
# the go build flags below + the compat_guard gate, NOT CMake's compiler vars.
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9)
set(CMAKE_OSX_ARCHITECTURES x86_64)

# Build-mode detection at configure time: "native" = compiling ON Mavericks 10.9
# (pkgsrc go126 present), "cross" = a modern host cross-compiling for 10.9. The build
# TARGET is always Mavericks; only the mode differs.
set(MVD_MODE "cross")
if(EXISTS "/opt/pkg/go126/bin/go")
  execute_process(COMMAND sw_vers -productVersion
    OUTPUT_VARIABLE _osv OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
  if(_osv MATCHES "^10\\.9\\.")
    set(MVD_MODE "native")
  endif()
endif()
message(STATUS "mavericks-docker ${MVD_VERSION} — build: ${MVD_MODE}")

# Require a per-mode preset: nothing may configure into an unqualified "build/" that
# can't tell native from cross (and would clobber the synced tree). The presets set
# MVD_EXPECTED_MODE + a distinct binaryDir (build-native / build-cross).
if(NOT DEFINED MVD_EXPECTED_MODE)
  message(FATAL_ERROR
    "Configure via a preset: 'cmake --preset native' on Mavericks, or "
    "'cmake --preset cross' on a modern host. Direct 'cmake -B <dir>' is disabled.")
endif()
# And fail fast if a preset is used on the wrong machine.
if(NOT MVD_EXPECTED_MODE STREQUAL MVD_MODE)
  message(FATAL_ERROR "preset expects a '${MVD_EXPECTED_MODE}' build but this machine "
    "does a '${MVD_MODE}' build — wrong preset for this host.")
endif()

# Pinned 10.9 SDK. native -> system SDK; cross -> fetch it.
set(MVD_MACOSX_10_9_SDK "" CACHE PATH "MacOSX10.9 SDK root (cross build)")
if(MVD_MODE STREQUAL "cross" AND NOT MVD_MACOSX_10_9_SDK)
  execute_process(COMMAND sh "${CMAKE_CURRENT_SOURCE_DIR}/cmake/fetch_10_9_sdk.sh"
    OUTPUT_VARIABLE _sdk OUTPUT_STRIP_TRAILING_WHITESPACE RESULT_VARIABLE _sdkrc)
  if(NOT _sdkrc EQUAL 0)
    message(FATAL_ERROR "fetch_10_9_sdk.sh failed")
  endif()
  set(MVD_MACOSX_10_9_SDK "${_sdk}" CACHE PATH "" FORCE)
endif()

# Per-mode toolchain + flags (mirrors the old build.sh host branches exactly).
if(MVD_MODE STREQUAL "native")
  set(MVD_GO  "/opt/pkg/go126/bin/go")
  # System clang (no pkgsrc gcc dependency). Requires go126 built with the cgoclang
  # SUBST (lang/go126/Makefile) so runtime/cgo compiles under the 2014 system clang.
  set(MVD_CC  "/usr/bin/clang")
  set(MVD_LS_ARCHS  "")
  set(MVD_LS_CFLAGS "")
  set(MVD_DC_ARCH   "")
  set(MVD_DC_SDK    "")
else()
  set(MVD_GO  "go")
  set(MVD_CC  "clang")
  set(MVD_LS_ARCHS  "x86_64")
  set(MVD_LS_CFLAGS "-isysroot ${MVD_MACOSX_10_9_SDK} -mmacosx-version-min=10.9")
  set(MVD_DC_ARCH   "-arch x86_64")
  set(MVD_DC_SDK    "-isysroot ${MVD_MACOSX_10_9_SDK}")
endif()

# Read a component's REPO/REF pin from components/<name>/version.
function(mvd_read_pin dir out_repo out_ref)
  file(STRINGS "${dir}/version" _lines)
  foreach(_l IN LISTS _lines)
    if(_l MATCHES "^REPO=(.+)$")
      set(_repo "${CMAKE_MATCH_1}")
    elseif(_l MATCHES "^REF=(.+)$")
      set(_ref "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  set(${out_repo} "${_repo}" PARENT_SCOPE)
  set(${out_ref}  "${_ref}"  PARENT_SCOPE)
endfunction()

include(ExternalProject)
enable_testing()

# --- component builds, gates, and unit tests ---
mvd_read_pin("${CMAKE_SOURCE_DIR}/components/legacy-support" LS_REPO LS_REF)
set(LS_OUT "${CMAKE_BINARY_DIR}/legacy-support")
set(LS_A   "${LS_OUT}/lib/libMacportsLegacySupport.a")
ExternalProject_Add(legacy_support
  GIT_REPOSITORY   "${LS_REPO}"
  GIT_TAG          "${LS_REF}"
  GIT_SHALLOW      TRUE
  UPDATE_DISCONNECTED TRUE   # pinned tag: clone once, don't re-fetch/rebuild each build
  BUILD_IN_SOURCE  TRUE
  CONFIGURE_COMMAND ""
  BUILD_COMMAND    sh "${CMAKE_SOURCE_DIR}/cmake/build_legacy_support.sh"
                     <SOURCE_DIR> "${LS_OUT}" "${MVD_CC}" "${MVD_LS_ARCHS}" "${MVD_LS_CFLAGS}"
  INSTALL_COMMAND  ""
  BUILD_BYPRODUCTS "${LS_A}"
)

# Shared, mode/host-independent cache for the (large) docker/cli source clone: fetched
# once, reused across build dirs and hosts instead of re-cloned per build. Ref-pinned
# path, so a version bump clones afresh. Override with -DMVD_SRC_CACHE=... if desired.
set(MVD_SRC_CACHE "${CMAKE_SOURCE_DIR}/.srccache" CACHE PATH
    "Shared cache dir for pinned dependency source clones")
mvd_read_pin("${CMAKE_SOURCE_DIR}/components/docker-cli" DC_REPO DC_REF)
set(DC_OUT     "${CMAKE_BINARY_DIR}/docker-cli")
set(DOCKER_BIN "${DC_OUT}/docker")
set(DC_SRC     "${MVD_SRC_CACHE}/docker-cli-${DC_REF}")
ExternalProject_Add(docker_cli
  DEPENDS          legacy_support
  SOURCE_DIR       "${DC_SRC}"
  DOWNLOAD_COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/clone_pinned.sh"
                     "${DC_REPO}" "${DC_REF}" "${DC_SRC}"
  UPDATE_COMMAND   ""
  BUILD_IN_SOURCE  TRUE
  CONFIGURE_COMMAND ""
  BUILD_COMMAND    sh "${CMAKE_SOURCE_DIR}/cmake/build_docker_cli.sh"
                     <SOURCE_DIR> "${DC_OUT}" "${MVD_GO}" "${MVD_CC}"
                     "${MVD_DC_ARCH}" "${MVD_DC_SDK}" "${LS_A}" "${DC_REF}"
  INSTALL_COMMAND  ""
  BUILD_BYPRODUCTS "${DOCKER_BIN}"
)

# docker-machine (GOPATH/dep era: no go.mod, vendored). Cloned into a GOPATH-shaped path
# so GO111MODULE=off can build it; the shim is injected via -extldflags (its only cgo is
# stdlib). Same go/CC/mode flags as docker-cli, so native + cross both work.
mvd_read_pin("${CMAKE_SOURCE_DIR}/components/docker-machine" DM_REPO DM_REF)
set(DM_GOPATH   "${MVD_SRC_CACHE}/docker-machine-${DM_REF}")
set(DM_SRC      "${DM_GOPATH}/src/github.com/docker/machine")
set(DM_OUT      "${CMAKE_BINARY_DIR}/docker-machine")
set(MACHINE_BIN "${DM_OUT}/docker-machine")
ExternalProject_Add(docker_machine
  DEPENDS          legacy_support
  SOURCE_DIR       "${DM_SRC}"
  DOWNLOAD_COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/clone_pinned.sh"
                     "${DM_REPO}" "${DM_REF}" "${DM_SRC}"
  UPDATE_COMMAND   ""
  BUILD_IN_SOURCE  TRUE
  CONFIGURE_COMMAND ""
  BUILD_COMMAND    sh "${CMAKE_SOURCE_DIR}/cmake/build_docker_machine.sh"
                     <SOURCE_DIR> "${DM_OUT}" "${MVD_GO}" "${MVD_CC}"
                     "${MVD_DC_ARCH}" "${MVD_DC_SDK}" "${LS_A}" "${DM_GOPATH}"
  INSTALL_COMMAND  ""
  BUILD_BYPRODUCTS "${MACHINE_BIN}"
)

# docker-compose (Compose v2; a go.mod module, not vendored). Simpler than docker-machine:
# a normal module build (deps from the shared module cache), shim via -extldflags.
mvd_read_pin("${CMAKE_SOURCE_DIR}/components/docker-compose" CO_REPO CO_REF)
set(CO_SRC      "${MVD_SRC_CACHE}/docker-compose-${CO_REF}")
set(CO_OUT      "${CMAKE_BINARY_DIR}/docker-compose")
set(COMPOSE_BIN "${CO_OUT}/docker-compose")
ExternalProject_Add(docker_compose
  DEPENDS          legacy_support
  SOURCE_DIR       "${CO_SRC}"
  DOWNLOAD_COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/clone_pinned.sh"
                     "${CO_REPO}" "${CO_REF}" "${CO_SRC}"
  UPDATE_COMMAND   ""
  BUILD_IN_SOURCE  TRUE
  CONFIGURE_COMMAND ""
  BUILD_COMMAND    sh "${CMAKE_SOURCE_DIR}/cmake/build_docker_compose.sh"
                     <SOURCE_DIR> "${CO_OUT}" "${MVD_GO}" "${MVD_CC}"
                     "${MVD_DC_ARCH}" "${MVD_DC_SDK}" "${LS_A}" "${CO_REF}"
  INSTALL_COMMAND  ""
  BUILD_BYPRODUCTS "${COMPOSE_BIN}"
)

# Fail-closed build-artifact gates (run after `cmake --build`).
add_test(NAME compat_guard
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/compat_guard.sh" "${DOCKER_BIN}")
add_test(NAME sdk_coverage
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/sdk_coverage.sh" "${DOCKER_BIN}")
add_test(NAME characterize
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/characterize_build.sh" compare
             "${CMAKE_SOURCE_DIR}/cmake/characterization/docker-cli" "${DOCKER_BIN}")
# characterize reads the binary's gomod via `go version -m`; use the SAME go that
# built it (MVD_GO), not whatever `go` is on PATH.
set_tests_properties(characterize PROPERTIES ENVIRONMENT "GO=${MVD_GO}")

# docker-machine through the same 10.9-safety gates.
add_test(NAME compat_guard_machine
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/compat_guard.sh" "${MACHINE_BIN}")
add_test(NAME sdk_coverage_machine
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/sdk_coverage.sh" "${MACHINE_BIN}")
# docker-compose through the same 10.9-safety gates.
add_test(NAME compat_guard_compose
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/compat_guard.sh" "${COMPOSE_BIN}")
add_test(NAME sdk_coverage_compose
  COMMAND sh "${CMAKE_SOURCE_DIR}/cmake/sdk_coverage.sh" "${COMPOSE_BIN}")

# Unit tests (script behavior + output invariants). Output-asserting ones take the
# built artifact path; self-contained ones run from the source tree.
add_test(NAME legacy_support_unit
  COMMAND sh "${CMAKE_SOURCE_DIR}/tests/legacy_support_test.sh" "${LS_A}")
add_test(NAME docker_cli_unit
  COMMAND sh "${CMAKE_SOURCE_DIR}/tests/docker_cli_test.sh" "${DOCKER_BIN}")
# These exercise the gate scripts against the built binary -> pass DOCKER_BIN so they
# work with any build dir (cmake -B <dir>), not a hardcoded build/.
add_test(NAME compat_guard_test
  COMMAND sh "${CMAKE_SOURCE_DIR}/tests/compat_guard_test.sh" "${DOCKER_BIN}")
add_test(NAME sdk_coverage_test
  COMMAND sh "${CMAKE_SOURCE_DIR}/tests/sdk_coverage_test.sh" "${DOCKER_BIN}")
add_test(NAME characterize_test
  COMMAND sh "${CMAKE_SOURCE_DIR}/tests/characterize_test.sh" "${DOCKER_BIN}")
# Self-contained (no built binary needed).
foreach(t fetch_sdk_test scaffold_test renovate_test)
  add_test(NAME ${t} COMMAND sh "${CMAKE_SOURCE_DIR}/tests/${t}.sh")
endforeach()
set_tests_properties(characterize_test PROPERTIES ENVIRONMENT "GO=${MVD_GO}")
