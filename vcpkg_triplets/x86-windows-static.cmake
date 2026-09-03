include("triplets/community/x86-windows-static.cmake")

include("../vcpkg_triplets/common/windows-static.cmake")

# Limit concurrency on 32-bit x86 Windows to avoid cl.exe D8040 child process communication errors
if(NOT DEFINED VCPKG_MAX_CONCURRENCY)
    set(VCPKG_MAX_CONCURRENCY 2)
endif()

# Disable ICF (Identical Code Folding) for 32-bit static builds: the final
# link of the combined static binary exceeds link.exe's 2-4GB memory limit.
# Override the common/windows-static.cmake setting.
set(VCPKG_LINKER_FLAGS_RELEASE "/OPT:REF /DEBUG:NONE")
