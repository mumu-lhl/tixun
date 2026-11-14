# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "tixun")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
set(APPLICATION_ID "org.tixun.tixun")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the unbundled copy, put it in a subdirectory instead of
# the default top-level location.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# By default, "installing" just makes a relocatable bundle in the build
# directory.
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Start with a clean build bundle directory every time.
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

# Build a separate embedded CPython executable for the Linux sandbox. Python
# code must never run in the Flutter application's process.
file(GLOB TIXUN_PYTHON_INCLUDE_DIRS LIST_DIRECTORIES true
  "${CMAKE_BINARY_DIR}/python/include/python*")
list(LENGTH TIXUN_PYTHON_INCLUDE_DIRS TIXUN_PYTHON_INCLUDE_COUNT)
if(NOT TIXUN_PYTHON_INCLUDE_COUNT EQUAL 1)
  message(FATAL_ERROR "Could not identify the bundled CPython headers")
endif()
list(GET TIXUN_PYTHON_INCLUDE_DIRS 0 TIXUN_PYTHON_INCLUDE_DIR)
get_filename_component(TIXUN_PYTHON_VERSION "${TIXUN_PYTHON_INCLUDE_DIR}" NAME)
string(REPLACE "python" "" TIXUN_PYTHON_VERSION "${TIXUN_PYTHON_VERSION}")
set(TIXUN_PYTHON_LIBRARY
  "${CMAKE_BINARY_DIR}/python/lib/libpython${TIXUN_PYTHON_VERSION}.so.1.0")
if(NOT EXISTS "${TIXUN_PYTHON_LIBRARY}")
  message(FATAL_ERROR "Bundled CPython shared library missing: ${TIXUN_PYTHON_LIBRARY}")
endif()
if(NOT TIXUN_PYTHON_VERSION STREQUAL "3.13")
  message(FATAL_ERROR "The sandbox launcher currently requires CPython 3.13; build with scripts/flutter_python.sh")
endif()
find_program(TIXUN_ZIG_EXECUTABLE zig)
if(NOT TIXUN_ZIG_EXECUTABLE)
  message(FATAL_ERROR "Zig 0.17.1 is required to build the Linux Python sandbox")
endif()
set(TIXUN_PYTHON_SANDBOX ${CMAKE_BINARY_DIR}/tixun-python-sandbox)
add_custom_command(
  OUTPUT "${TIXUN_PYTHON_SANDBOX}"
  COMMAND "${TIXUN_ZIG_EXECUTABLE}" build-exe
    "${CMAKE_CURRENT_SOURCE_DIR}/python_sandbox.zig"
    -O ReleaseFast
    "${TIXUN_PYTHON_LIBRARY}"
    -lc
    -rpath "$ORIGIN/../lib"
    "-femit-bin=${TIXUN_PYTHON_SANDBOX}"
  DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/python_sandbox.zig"
          "${TIXUN_PYTHON_LIBRARY}"
  VERBATIM
  COMMENT "Building isolated CPython launcher with Zig")
add_custom_target(tixun-python-sandbox-build ALL DEPENDS "${TIXUN_PYTHON_SANDBOX}")
install(PROGRAMS "${TIXUN_PYTHON_SANDBOX}"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/libexec" COMPONENT Runtime)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()
