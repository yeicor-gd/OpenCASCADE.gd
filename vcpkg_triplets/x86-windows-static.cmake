include("triplets/community/x86-windows-static.cmake")

include("../vcpkg_triplets/common/windows-static.cmake")

# Explicitly disable ICF (Identical Code Folding) for 32-bit static builds to prevent
# memory exhaustion during linking.
set(VCPKG_LINKER_FLAGS_RELEASE "/OPT:REF /OPT:NOICF /DEBUG:NONE")
