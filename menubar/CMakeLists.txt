cmake_minimum_required(VERSION 3.16)
# Menu-bar app for the container-tools product. Standalone project like updater/ (built
# on its own: `cmake -S menubar -B build/menubar`). Native ObjC, x86_64 / min-10.9.
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "runs on the 10.9 box")
set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "Intel-only (10.9)")
project(DockerMenu LANGUAGES OBJC)
find_package(MavericksSharedCMake REQUIRED)
set(MAVERICKS_REQUIRE_LANGS OBJC)
include(Mavericks)   # AppleClang gate + build conventions

file(STRINGS "${CMAKE_SOURCE_DIR}/../VERSION" MAVERICKS_DOCKER_VERSION LIMIT_COUNT 1)

add_executable(DockerMenu MACOSX_BUNDLE
  main.m AppDelegate.m MDController.m MDWatchers.m MDLoginItem.m)
target_compile_options(DockerMenu PRIVATE -fobjc-arc -Wall)
set_target_properties(DockerMenu PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info.plist.in"
  MACOSX_BUNDLE_BUNDLE_NAME "Container Tools for Mavericks"
  MACOSX_BUNDLE_GUI_IDENTIFIER "dev.modernmavericks.DockerMenu"
  MACOSX_BUNDLE_BUNDLE_VERSION "${MAVERICKS_DOCKER_VERSION}"
  MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0")
target_link_libraries(DockerMenu "-framework Cocoa" "-framework CoreServices")
