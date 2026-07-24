include("triplets/community/wasm32-emscripten.cmake")

# ── CUSTOM: propagate CFLAGS/CXXFLAGS to all vcpkg port builds ──────────
#
# The vcpkg binary evaluates the overlay triplet and passes only *standard*
# variables (VCPKG_CXX_FLAGS, VCPKG_CRT_LINKAGE, etc.) as -D defines to
# dependency port cmake processes.  Non-standard variables like
# VCPKG_CMAKE_CONFIGURE_OPTIONS are silently dropped, so they cannot be
# used to set CMAKE_CXX_FLAGS for freetype/libpng/opencascade.
#
# Instead we:
#   1. Compute the needed flags below.
#   2. Forward CFLAGS/CXXFLAGS through vcpkg's env-sanitisation via
#      VCPKG_ENV_PASSTHROUGH_UNTRACKED (so the vcpkg binary passes them
#      to every cmake subprocess it spawns for port builds).
#   3. CMake natively reads CFLAGS → CMAKE_C_FLAGS, CXXFLAGS → CMAKE_CXX_FLAGS.
# ─────────────────────────────────────────────────────────────────────────

# Always forward CFLAGS/CXXFLAGS through vcpkg's build environment.
list(APPEND VCPKG_ENV_PASSTHROUGH_UNTRACKED CFLAGS CXXFLAGS)

# --- Read GDEXT_CMAKE_ARGS to detect thread configuration ---
if(EXISTS "${SOURCE_PATH}/__GDEXT_CMAKE_ARGS")
  file(READ "${SOURCE_PATH}/__GDEXT_CMAKE_ARGS" GDEXT_CMAKE_ARGS)
elseif(DEFINED ENV{GDEXT_CMAKE_ARGS})
  set(GDEXT_CMAKE_ARGS "$ENV{GDEXT_CMAKE_ARGS}")
else()
  message(FATAL_ERROR "GDEXT_CMAKE_ARGS environment variable OR ${SOURCE_PATH}/__GDEXT_CMAKE_ARGS file not set.")
endif()
separate_arguments(GDEXT_CMAKE_ARGS UNIX_COMMAND "${GDEXT_CMAKE_ARGS}")

set(_threads_enabled OFF)
foreach(_arg IN LISTS GDEXT_CMAKE_ARGS)
  if(_arg MATCHES "^-DGODOTCPP_THREADS[:=](on|ON|1|true|TRUE)$")
    set(_threads_enabled ON)
    break()
  endif()
endforeach()

# --- Compute per-language flag strings ---
set(_common_flags "-fPIC")

if(_threads_enabled)
  string(APPEND _common_flags " -matomics -mbulk-memory")
endif()

# wasm-native setjmp/longjmp (patch 0007 disables OCC_CONVERT_SIGNALS,
# patch 0008 removes -fexceptions, so no conflict with -fwasm-exceptions).
string(APPEND _common_flags " -sSUPPORT_LONGJMP=wasm")

# wasm-native C++ exceptions (Godot main module provides __cpp_exception tag).
string(APPEND _common_flags " -fwasm-exceptions")

# --- Set CFLAGS/CXXFLAGS in the triplet's cmake scope ---
# These become the initial values exported via VCPKG_ENV_PASSTHROUGH_UNTRACKED
# so every dependency port cmake picks them up.
set(ENV{CFLAGS}  "${_common_flags}")
set(ENV{CXXFLAGS} "${_common_flags}")

