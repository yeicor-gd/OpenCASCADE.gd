include("triplets/arm64-osx.cmake")

include("../vcpkg_triplets/common/arm64.cmake")

set(VCPKG_TARGET_ARCHITECTURE universal)
set(VCPKG_OSX_ARCHITECTURES arm64;x86_64)

# Use line-tables-only for debug builds to avoid lipo running out of disk space on 11,000+ universal object files
set(VCPKG_C_FLAGS_DEBUG "-gline-tables-only")
set(VCPKG_CXX_FLAGS_DEBUG "-gline-tables-only")
