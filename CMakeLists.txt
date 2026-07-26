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

# Define the documentation sources (the godot-cpp cmake version does not
# work?)
if(GODOTCPP_TARGET MATCHES "editor|template_debug")
  find_package(Python3 3.4 REQUIRED) # pathlib should be present
  file(GLOB_RECURSE DOC_XML LIST_DIRECTORIES NO CONFIGURE_DEPENDS
        "${PROJECT_SOURCE_DIR}/doc_classes/*.xml"
        "${PROJECT_SOURCE_DIR}/doc_classes/**/*.xml")
  set(DOC_GEN_FILE "${CMAKE_CURRENT_BINARY_DIR}/gen/doc_data.cpp")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/gen")
  set(PYTHON_LIST "'${DOC_XML}'")
  list(JOIN PYTHON_LIST "','" PYTHON_LIST)
  add_custom_command(
    OUTPUT ${DOC_GEN_FILE}
    COMMAND ${Python3_EXECUTABLE} "-c"
        "from doc_source_generator import generate_doc_source; generate_doc_source('${DOC_GEN_FILE}', [${PYTHON_LIST}])"
    VERBATIM
    WORKING_DIRECTORY
        ${CMAKE_CURRENT_SOURCE_DIR}/godot-cpp
    DEPENDS ${DOC_XML})
  add_custom_target(generate_doc_data DEPENDS ${DOC_GEN_FILE})
endif()

# Define the shared library target
# Hand-written sources + autowrapper-generated sources
file(GLOB_RECURSE SOURCES
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

# Force-include the auto-generated OCCT compatibility header.
# It provides all transitive OCCT dependencies in topological order,
# derived from libclang's include graphs (no hardcoded library knowledge).
target_compile_options(${PROJECT_NAME} PRIVATE
  "-include" "${CMAKE_CURRENT_SOURCE_DIR}/src/autowrapper/occt_compat.hxx"
)

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
set_source_files_properties(${SOURCES} PROPERTIES COMPILE_OPTIONS "${WARN_FLAGS}")

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
