include("triplets/community/arm64-windows-static.cmake")

include("../vcpkg_triplets/common/arm64.cmake")
include("../vcpkg_triplets/common/windows-static.cmake")

# Workaround for ARM64 Windows Debug builds:
# link.exe runs out of memory (14GB+ RAM) trying to index or merge debug records
# for thousands of autowrapper object files and OpenCASCADE static libraries.
# To make arm64-windows-static debug builds linkable within GitHub Actions runner limits,
# debug info is disabled entirely (build unoptimized without debug info: /Od /Ob0 /RTC1,
# but /DEBUG:NONE and no /Zi or /Z7).
set(VCPKG_CXX_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /RTC1")
set(VCPKG_C_FLAGS_DEBUG "/D_DEBUG /MTd /Ob0 /Od /RTC1")
set(VCPKG_LINKER_FLAGS_DEBUG "/DEBUG:NONE")

