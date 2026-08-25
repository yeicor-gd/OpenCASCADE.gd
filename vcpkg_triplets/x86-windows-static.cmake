include("triplets/community/x86-windows-static.cmake")

include("../vcpkg_triplets/common/windows-static.cmake")

# Limit concurrency on 32-bit x86 Windows to avoid cl.exe D8040 child process communication errors
if(NOT DEFINED VCPKG_MAX_CONCURRENCY)
    set(VCPKG_MAX_CONCURRENCY 2)
endif()
