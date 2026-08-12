# Portfile for the Godot extension of this project
# ABI change to force rebuild - v2

# The dependencies are specified in vcpkg.json

set(SOURCE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../")

if(EXISTS "${SOURCE_PATH}/__GDEXT_CMAKE_ARGS")
    file(READ "${SOURCE_PATH}/__GDEXT_CMAKE_ARGS" GDEXT_CMAKE_ARGS)
elseif(DEFINED ENV{GDEXT_CMAKE_ARGS})
    set(GDEXT_CMAKE_ARGS "$ENV{GDEXT_CMAKE_ARGS}")
else()
    message(FATAL_ERROR "GDEXT_CMAKE_ARGS environment variable OR ${SOURCE_PATH}/__GDEXT_CMAKE_ARGS file not set.")
endif()
separate_arguments(GDEXT_CMAKE_ARGS UNIX_COMMAND "${GDEXT_CMAKE_ARGS}")

# The gdext build compiles thousands of autowrapper translation units; the
# default VCPKG_CONCURRENCY (cores+1) makes small CI runners run out of memory
# (SIGTERM/exit 143 at "Building ..." when the allocator is starved).  Bound
# the build parallelism to a fraction of the cores, honoring an explicit
# VCPKG_MAX_CONCURRENCY override (the knob vcpkg itself exposes).
cmake_host_system_information(RESULT _gdext_ncores QUERY NUMBER_OF_LOGICAL_CORES)
set(_gdext_cores_cap 4)
if(_gdext_ncores LESS _gdext_cores_cap)
    set(_gdext_cores_cap "${_gdext_ncores}")
endif()
if(NOT DEFINED ENV{VCPKG_MAX_CONCURRENCY} AND
   (NOT DEFINED VCPKG_CONCURRENCY OR VCPKG_CONCURRENCY GREATER _gdext_cores_cap))
    set(VCPKG_CONCURRENCY "${_gdext_cores_cap}")
    message(STATUS "gdext: capping VCPKG_CONCURRENCY to ${VCPKG_CONCURRENCY} "
                   "to bound peak memory (set VCPKG_MAX_CONCURRENCY to override)")
endif()

vcpkg_configure_cmake(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS ${GDEXT_CMAKE_ARGS}
    MAYBE_UNUSED_VARIABLES GODOTCPP_PRECISION GODOTCPP_THREADS
)

vcpkg_build_cmake(TARGET install)

set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
