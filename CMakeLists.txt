cmake_minimum_required(VERSION 3.25)

include(CheckCXXCompilerFlag)

message(STATUS "Using toolchain file: " "${CMAKE_TOOLCHAIN_FILE}")
option(ENABLE_WERROR "Enable warnings as errors (ON|OFF)" OFF)
option(ENABLE_SANITIZERS "Enable sanitizers (ON|OFF)" OFF)
# Auto-force full LTO in release builds if available
if(CMAKE_BUILD_TYPE STREQUAL "Release")
  include(CheckIPOSupported)
  check_ipo_supported(RESULT IPO_SUPPORTED OUTPUT IPO_SUPPORT_OUTPUT)
  if(IPO_SUPPORTED)
    message(STATUS "IPO (LTO) is supported, enabling it for Release builds")
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(WARNING "IPO (LTO) is not supported: "
            "${IPO_SUPPORT_OUTPUT}")
  endif()
else()
  message(STATUS "IPO (LTO) is not enabled for Debug "
        "builds")
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
project(OpenCASCADE.gd CXX)  # OpenCASCADE Technology wrapper for Godot

# Automatically use ccache or sccache as a compiler launcher when one is
# available on the system. This dramatically speeds up the incremental
# rebuilds that vcpkg --editable performs after each autowrapper
# regeneration (only changed translation units need recompiling).
find_program(CCACHE_PROGRAM ccache)
find_program(SCCACHE_PROGRAM sccache)
if(CCACHE_PROGRAM OR SCCACHE_PROGRAM)
  if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    set(CMAKE_C_COMPILER_LAUNCHER "${CCACHE_PROGRAM}")
    message(STATUS "Using ccache for compilation: ${CCACHE_PROGRAM}")
  else()
    set(CMAKE_CXX_COMPILER_LAUNCHER "${SCCACHE_PROGRAM}")
    set(CMAKE_C_COMPILER_LAUNCHER "${SCCACHE_PROGRAM}")
    message(STATUS "Using sccache for compilation: ${SCCACHE_PROGRAM}")
  endif()
endif()

# Check that both CMAKE_BUILD_TYPE and GODOTCPP_TARGET are set correctly
# (always required)
if (NOT CMAKE_BUILD_TYPE STREQUAL "Release" AND
    NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
  message(FATAL_ERROR "CMAKE_BUILD_TYPE must be either 'Release' or 'Debug'. "
        "Current value: ${CMAKE_BUILD_TYPE}")
endif ()
if (NOT GODOTCPP_TARGET STREQUAL "template_release" AND
    NOT GODOTCPP_TARGET STREQUAL "template_debug")
  message(FATAL_ERROR "GODOTCPP_TARGET must be either 'template_release' or "
        "'template_debug'. Current value: ${GODOTCPP_TARGET}")
endif ()
message(STATUS "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}, "
    "GODOTCPP_TARGET: ${GODOTCPP_TARGET}")

# No-op when CMAKE_BUILD_TYPE does not match the GODOTCPP_TARGET
# (it can make sense, but it is rare enough to not be worth building them by default)
if (CMAKE_BUILD_TYPE STREQUAL "Release" AND NOT GODOTCPP_TARGET STREQUAL "template_release")
  message(WARNING "CMAKE_BUILD_TYPE is 'Release' but GODOTCPP_TARGET is not 'template_release'. Ignoring this build to speed up the build process.")
  install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/README.md" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/") # No-op installation
  return()
endif ()
if (CMAKE_BUILD_TYPE STREQUAL "Debug" AND NOT GODOTCPP_TARGET STREQUAL "template_debug")
  message(WARNING "CMAKE_BUILD_TYPE is 'Debug' but GODOTCPP_TARGET is not 'template_debug'. Ignoring this build to speed up the build process.")
  install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/README.md" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/") # No-op installation
  return()
endif ()

# Fix CMAKE_OSX_SYSROOT for iOS to use full SDK path (overriden incorrectly by godot-cpp due to env SDKROOT)
set(ENV{SDKROOT} "${CMAKE_OSX_SYSROOT}")
set(GODOTCPP_DISABLE_EXCEPTIONS ON)

# Godot C++ bindings
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp")

# Dependencies
# OpenCASCADE (consumed via vcpkg).
find_package(OpenCASCADE REQUIRED)

# Regenerate the OCCT autowrapper bindings at configure time, so a from-scratch
# "vcpkg install gdext" works in one run: the deps (OCCT headers) are already
# installed above, and the wrappers are written before the source GLOB below
# picks them up.  Wrappers are only regenerated when needed:
#   - no stamp file yet (fresh checkout), or
#   - the OCCT version in the stamp differs from the one just found, or
#   - any generator source (autogen/*.py) is newer than the stamp.
# A previous configure that already generated (or a manual generate.sh run)
# leaves the stamp in place, so the regeneration is not repeated.
set(AUTOWRAPPER_DIR "${PROJECT_SOURCE_DIR}/OpenCASCADE.gd-autowrapper")
set(AUTOWRAPPER_STAMP "${PROJECT_SOURCE_DIR}/src/autowrapper/.autowrapper-stamp")
set(AUTOWRAPPER_NEED_REGEN FALSE)
if (NOT EXISTS "${AUTOWRAPPER_STAMP}")
  set(AUTOWRAPPER_NEED_REGEN TRUE)
  message(STATUS "OpenCASCADE autowrapper: no stamp, will regenerate")
else()
  file(STRINGS "${AUTOWRAPPER_STAMP}" _stamp_lines)
  set(_stamp_occt "")
  foreach(_l IN LISTS _stamp_lines)
    if (_l MATCHES "^occt=(.*)$")
      set(_stamp_occt "${CMAKE_MATCH_1}")
      break()
    endif()
  endforeach()
  if (NOT "${_stamp_occt}" STREQUAL "${OpenCASCADE_VERSION}")
    set(AUTOWRAPPER_NEED_REGEN TRUE)
    message(STATUS "OpenCASCADE autowrapper: OCCT version changed "
        "(${_stamp_occt} -> ${OpenCASCADE_VERSION}), will regenerate")
  else()
    file(GLOB_RECURSE _gen_srcs "${AUTOWRAPPER_DIR}/autogen/*.py")
    foreach(_s IN LISTS _gen_srcs)
      if ("${_s}" IS_NEWER_THAN "${AUTOWRAPPER_STAMP}")
        set(AUTOWRAPPER_NEED_REGEN TRUE)
        message(STATUS "OpenCASCADE autowrapper: generator sources newer than "
            "stamp (${_s}), will regenerate")
        break()
      endif()
    endforeach()
  endif()
endif()
if (AUTOWRAPPER_NEED_REGEN)
  # CI installs the python clang bindings into a specific interpreter recorded
  # in $PYTHON; prefer it over find_package so the regeneration uses the exact
  # python that can import clang.cindex (find_package may pick a different one).
  if (DEFINED ENV{PYTHON} AND NOT "$ENV{PYTHON}" STREQUAL "")
    set(_autogen_python "$ENV{PYTHON}")
  else()
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    set(_autogen_python "${Python3_EXECUTABLE}")
  endif()
  # Bound the scan/parse parallelism the same way generate.sh does (each scan
  # worker is a separate libclang process parsing large OCCT headers; on small
  # runners oversubscription starves memory).
  cmake_host_system_information(RESULT _nproc QUERY NUMBER_OF_LOGICAL_CORES)
  if (NOT _nproc MATCHES "^[0-9]+$" OR _nproc EQUAL 0)
    set(_nproc 4)
  endif()
  if (DEFINED ENV{GITHUB_ACTIONS})
    if (_nproc GREATER_EQUAL 4)
      set(_autogen_jobs 4)
    else()
      set(_autogen_jobs "${_nproc}")
    endif()
  else()
    set(_autogen_jobs "${_nproc}")
  endif()
  if (_autogen_jobs LESS 1)
    set(_autogen_jobs 1)
  endif()
  # The generator locates the OCCT include dir via VCPKG_DEFAULT_TRIPLET.
  if (DEFINED VCPKG_TARGET_TRIPLET)
    set(ENV{VCPKG_DEFAULT_TRIPLET} "${VCPKG_TARGET_TRIPLET}")
  endif()
  message(STATUS "OpenCASCADE autowrapper: regenerating bindings "
      "(occt ${OpenCASCADE_VERSION}, jobs ${_autogen_jobs})...")
  execute_process(
    COMMAND "${_autogen_python}" -m autogen regenerate --jobs "${_autogen_jobs}"
    WORKING_DIRECTORY "${AUTOWRAPPER_DIR}"
    RESULT_VARIABLE _autogen_rc
    OUTPUT_VARIABLE _autogen_out
    ERROR_VARIABLE _autogen_err)
  if (_autogen_out)
    message(STATUS "OpenCASCADE autowrapper output:\n${_autogen_out}")
  endif()
  if (_autogen_err)
    message(STATUS "OpenCASCADE autowrapper stderr:\n${_autogen_err}")
  endif()
  if (NOT _autogen_rc EQUAL 0)
    message(FATAL_ERROR "OpenCASCADE autowrapper generation failed (rc=${_autogen_rc}):\n"
        "${_autogen_out}\n${_autogen_err}")
  endif()
endif()

# Define the documentation sources (the godot-cpp cmake version does not
# work?)
if(GODOTCPP_TARGET MATCHES "editor|template_debug")
  find_package(Python3 3.4 REQUIRED) # pathlib should be present
  file(GLOB_RECURSE DOC_XML LIST_DIRECTORIES NO CONFIGURE_DEPENDS
        "${PROJECT_SOURCE_DIR}/doc_classes/*.xml"
        "${PROJECT_SOURCE_DIR}/doc_classes/autowrapper/*.xml")
  set(DOC_GEN_FILE "${CMAKE_CURRENT_BINARY_DIR}/gen/doc_data.cpp")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/gen")
  # Note: paths are not passed on the command line (that would exceed
  # MAX_ARG_STRLEN once there are thousands of generated doc XML files);
  # the generator globs the directory itself.
  add_custom_command(
    OUTPUT ${DOC_GEN_FILE}
    COMMAND ${Python3_EXECUTABLE} "-c"
        "from doc_source_generator import generate_doc_source_from_directory; generate_doc_source_from_directory('${DOC_GEN_FILE}', '${PROJECT_SOURCE_DIR}/doc_classes/autowrapper')"
    VERBATIM
    WORKING_DIRECTORY
        ${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp
    DEPENDS ${DOC_XML})
  add_custom_target(generate_doc_data DEPENDS ${DOC_GEN_FILE})
endif()

# Define the shared library target
# Hand-written sources + autowrapper-generated sources
# CONFIGURE_DEPENDS: re-glob automatically when the autowrapper is
# regenerated (new/deleted TUs), so builds stay incremental without a
# manual cmake re-run. Unchanged files keep their mtimes and are skipped.
file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS
    "src/*.cpp"
    "src/**/*.cpp"
    "src/autowrapper/*.cpp"
    "src/autowrapper/**/*.cpp"
)
# Ensure autowrapper directories exist (even if empty, for glob to work)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/src/autowrapper")
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  add_library(${PROJECT_NAME} MODULE ${SOURCES} ${DOC_GEN_FILE})
  # SIDE_MODULE=2 bundles system libraries (libc++, compiler-rt) into the
  # extension so it doesn't need to import them from the main module (Godot).
  target_link_options(${PROJECT_NAME} PRIVATE
    "-sSIDE_MODULE=2"
    "-sEXPORTED_FUNCTIONS=_gdext_library_init"
  )
else()
  add_library(${PROJECT_NAME} SHARED ${SOURCES} ${DOC_GEN_FILE})
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten" OR MINGW)
  # Avoid failing on duplicate definitions for Emscripten and mingw compilers
  target_link_libraries(${PROJECT_NAME} PRIVATE "-Wl,--allow-multiple-definition")
endif()
# GNU ld (bfd) cannot synthesize the range-extension thunks this very large
# shared library needs on AArch64: calls between the far ends of the .so
# exceed the +/-128MB range of R_AARCH64_CALL26/JUMP26, and the link dies with
# "relocation truncated to fit" (binutils ld/18668, e.g. against libgcc's
# __aarch64_ldadd4_rel outline-atomics helper and godot-cpp's
# add_engine_class_registration_callback).  LLD inserts thunks robustly, so
# prefer it for native AArch64 Linux links (CI installs lld-22 via llvm.sh).
if(CMAKE_SYSTEM_NAME STREQUAL "Linux"
   AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  # `-fuse-ld=lld` makes GCC search PATH for an unversioned `ld.lld`; the
  # CI symlinks it from the llvm.sh lld-22 install.
  find_program(GDEXT_LLD NAMES ld.lld)
  if(GDEXT_LLD)
    message(STATUS "AArch64 Linux: linking with LLD (${GDEXT_LLD})")
    target_link_options(${PROJECT_NAME} PRIVATE "-fuse-ld=lld")
  else()
    message(WARNING "AArch64 Linux: LLD not found; the shared library may "
            "fail to link with 'relocation truncated to fit' (GNU ld veneer bug)")
  endif()
endif()
# Link godot-cpp and OpenCASCADE.
# The OpenCASCADE cmake config provides imported targets in per-module
# *Targets.cmake files.  We include them all to make every TK* target
# available, then link against the full set via OpenCASCADE_LIBRARIES.
file(GLOB _OCC_MODULE_FILES "${OpenCASCADE_DIR}/OpenCASCADE*Targets.cmake")
foreach(_f ${_OCC_MODULE_FILES})
  include("${_f}")
endforeach()
target_link_libraries(${PROJECT_NAME} PRIVATE godot-cpp ${OpenCASCADE_LIBRARIES})
target_include_directories(${PROJECT_NAME} PRIVATE src)
target_include_directories(${PROJECT_NAME} SYSTEM PRIVATE ${OpenCASCADE_INCLUDE_DIR})
target_include_directories(${PROJECT_NAME} SYSTEM PRIVATE src/autowrapper)
get_target_property(GODOTCPP_INCLUDES godot-cpp INTERFACE_INCLUDE_DIRECTORIES)
target_include_directories(${PROJECT_NAME} SYSTEM PRIVATE ${GODOTCPP_INCLUDES})

# Define NOMINMAX and WIN32_LEAN_AND_MEAN to prevent windows.h macro collisions
target_compile_definitions(${PROJECT_NAME} PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)

# Force-include the exception guard header. It defines the OCCT signal/exception
# catch machinery used by the generated wrappers (OCC_CATCH_SIGNALS, OCCT_GUARD_*).
# Every generated header/source includes exactly the OCCT headers it needs itself.
# MSVC ignores the GCC-style `-include` flag (D9002) and would compile every TU
# without the guard macros; it needs the MSVC `/FI` force-include form instead.
if(MSVC)
  target_compile_options(${PROJECT_NAME} PRIVATE
    "/FI${CMAKE_CURRENT_SOURCE_DIR}/src/occt_guard.hxx"
    "/utf-8"
    "/wd4828"
    "/bigobj"
  )
else()
  target_compile_options(${PROJECT_NAME} PRIVATE
    "SHELL:-include ${CMAKE_CURRENT_SOURCE_DIR}/src/occt_guard.hxx"
  )
endif()

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  # Wrapper TUs contain thousands of methods whose debug DIEs and variable-tracking
  # consume gigabytes of memory per compiler worker. -g1 and -fno-var-tracking
  # keep essential line-number information while slashing peak memory by ~80%,
  # avoiding OOM kills on high-parallelism CI runners.
  target_compile_options(${PROJECT_NAME} PRIVATE
    "$<$<CONFIG:Debug>:-g1;-fno-var-tracking>"
  )
endif()

if(MSVC) # Maximum warnings and treat them as errors
  set(WARN_FLAGS "/W4")
  if(ENABLE_WERROR)
    list(APPEND WARN_FLAGS "/WX")
  endif()
else()
  set(WARN_FLAGS "-Wall;-Wextra;-Wpedantic")
  if(ENABLE_WERROR)
    list(APPEND WARN_FLAGS "-Werror")
  endif()
endif()
target_compile_options(${PROJECT_NAME} PRIVATE "${WARN_FLAGS}")

# Also figure out runtime issues in debug builds with sanitizers if supported by the compiler
if(ENABLE_SANITIZERS)
  function(enable_sanitizers target)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
      # Exit if using standard MinGW-GCC (prevents your original link error)
      if(MINGW AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        message(STATUS "Sanitizers skipped: MinGW GCC lacks support.")
        return()
      endif()
      # 1. Start with Address and Undefined Behavior
      set(SAN_FLAGS "-fsanitize=address,undefined")
      # 2. Add Leak Sanitizer (LSan) - often bundled with ASan
      check_cxx_compiler_flag("-fsanitize=leak" HAS_LSAN)
      if(HAS_LSAN)
        set(SAN_FLAGS "${SAN_FLAGS},leak")
      endif()
      # 4. Add Stack Smashing Protection
      target_compile_options(${target} PRIVATE $<$<CONFIG:Debug>:-fstack-protector-all>)
      # Apply flags
      target_compile_options(${target} PRIVATE $<$<CONFIG:Debug>:${SAN_FLAGS} -static-libasan -fno-omit-frame-pointer -g>)
      target_link_options(${target} PRIVATE $<$<CONFIG:Debug>:${SAN_FLAGS} -static-libasan>)
    elseif(MSVC)
      # 1. Basic Runtime Checks (Buffer overflows, uninitialized variables, etc.)
      target_compile_options(${target} PRIVATE $<$<CONFIG:Debug>:/RTC1>)
    endif()
  endfunction()
  enable_sanitizers(${PROJECT_NAME})
endif()

# Install the complete bindings to the demo project with the correct suffix
get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)
if(NOT GODOTCPP_SUFFIX)
  message(FATAL_ERROR "GODOTCPP_SUFFIX property not set on godot-cpp target.")
endif()
string(TOLOWER "${CMAKE_BUILD_TYPE}" BUILD_TYPE_LOWER)
string(REPLACE ".template_" ".${BUILD_TYPE_LOWER}.template_" GODOTCPP_SUFFIX "${GODOTCPP_SUFFIX}") # Allow .debug.template_release and vice versa
set(OUTPUT_NAME "gdext${GODOTCPP_SUFFIX}")
if (MINGW) # Avoid name collision for both supported windows compilers (msvc and mingw)
  set(OUTPUT_NAME "gdext${GODOTCPP_SUFFIX}.mingw")
endif()
set(INSTALL_FOLDER "${CMAKE_CURRENT_SOURCE_DIR}/demo/addons/${PROJECT_NAME}")
message("Will install shared library to: ${INSTALL_FOLDER}")
set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "${OUTPUT_NAME}")
set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "lib") # Unix-like behavior on windows too: lib*.dll
install(TARGETS ${PROJECT_NAME} LIBRARY DESTINATION "${INSTALL_FOLDER}")

# Post-build: repair Emscripten wasm validation bugs (br_table arity mismatches
# that crash at runtime) and optimize the .so.
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  find_program(PYTHON3_EXECUTABLE python3 REQUIRED)
  add_custom_command(
    TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E env
            "DEBUG=$<IF:$<CONFIG:Debug>,1,>"
            "EMSDK=$ENV{EMSDK}"
            ${PYTHON3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tools/repair_wasm.py
            $<TARGET_FILE_DIR:${PROJECT_NAME}> $<TARGET_FILE_DIR:${PROJECT_NAME}>
    COMMENT "Repairing and optimizing WASM binary..."
    VERBATIM
  )
endif()
