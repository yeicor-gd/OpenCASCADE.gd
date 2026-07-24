include("triplets/arm64-osx.cmake")

include("../vcpkg_triplets/common/arm64.cmake")

set(VCPKG_TARGET_ARCHITECTURE universal)
set(VCPKG_OSX_ARCHITECTURES arm64;x86_64)
