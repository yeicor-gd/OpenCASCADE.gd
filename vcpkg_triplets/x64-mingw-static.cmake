include("triplets/community/x64-mingw-static.cmake")

# Large generated sources exceed GCC default object file section capacity;
# allow the assembler to use the big-object format.
set(VCPKG_C_FLAGS "${VCPKG_C_FLAGS} -Wa,-mbig-obj")
set(VCPKG_CXX_FLAGS "${VCPKG_CXX_FLAGS} -Wa,-mbig-obj")
