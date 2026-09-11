include("triplets/community/x86-windows-static.cmake")

include("../vcpkg_triplets/common/windows-static.cmake")

# Explicitly disable ICF (Identical Code Folding) for 32-bit static builds to prevent
# memory exhaustion during linking.
set(VCPKG_LINKER_FLAGS_RELEASE "/OPT:REF /OPT:NOICF /DEBUG:NONE")

# Use /O1 and /d2notmpopt for 32-bit release builds to avoid MSVC C1001 optimizer internal compiler error
set(VCPKG_CXX_FLAGS_RELEASE "/O1 /Oi /Gy /DNDEBUG /Z7 /d2notmpopt")
set(VCPKG_C_FLAGS_RELEASE "/O1 /Oi /Gy /DNDEBUG /Z7 /d2notmpopt")
