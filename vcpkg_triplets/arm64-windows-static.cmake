include("triplets/community/arm64-windows-static.cmake")

include("../vcpkg_triplets/common/arm64.cmake")
include("../vcpkg_triplets/common/windows-static.cmake")

# UGLY HACK for ARM64 Windows Debug builds:
# OpenCASCADE and other dependencies provide massive static libraries. When compiled with
# debug info (/Zi or /Z7), those static libraries contain gigabytes of CodeView records.
# When linking the monolithic OpenCASCADE.gd.dll on ARM64 with link.exe, merging all dependency
# debug records pushes memory to >13.65 GB RAM, exhausting the 16 GB runner memory and causing
# catastrophic pagefile thrashing that times out after 4.5 hours.
# To make linking viable within runner memory limits while still providing crash/debug info for
# the autowrapper code itself:
# 1. Strip /Zi and /Z7 from dependency C/CXX flags for arm64-windows-static debug builds.
# 2. Set dependency debug linker flags to /DEBUG:NONE.
# The autowrapper (gdext) keeps debug enabled in CMakeLists.txt so that crashes in wrapper code
# still produce meaningful function names/line numbers without the OpenCASCADE static library bloat.
if(NOT PORT STREQUAL "gdext")
  set(VCPKG_CXX_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /RTC1")
  set(VCPKG_C_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /RTC1")
  set(VCPKG_LINKER_FLAGS_DEBUG "/DEBUG:NONE")
endif()

