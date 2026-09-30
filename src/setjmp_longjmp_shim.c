// setjmp_longjmp_shim.c
//
// With -sSUPPORT_LONGJMP=wasm in the vcpkg triplet, the compiler lowers all
// setjmp/longjmp calls to __wasm_setjmp/__wasm_longjmp intrinsics.  These
// are normally provided by Emscripten's compiler-rt, but in a SIDE_MODULE=2
// build they cannot be imported from the main module (Godot) because:
//   1. With -fwasm-exceptions, the main module doesn't include JS-based
//      emscripten_longjmp/emscripten_setjmp
//   2. __wasm_setjmp/__wasm_longjmp are compiler intrinsics that don't
//      appear in the main module's wasm export table
//
// This shim defines __wasm_setjmp/__wasm_longjmp locally using the wasm EH
// builtins __builtin_setjmp/__builtin_longjmp.  With -fwasm-exceptions these
// builtins generate the correct wasm-native setjmp/longjmp code, and the
// jmp_buf format matches what -sSUPPORT_LONGJMP=wasm expects.

#ifdef __EMSCRIPTEN__

int __wasm_setjmp(void *buf) {
    return __builtin_setjmp(buf);
}

void __wasm_longjmp(void *buf, int val) {
    __builtin_longjmp(buf, val);
}

#endif /* __EMSCRIPTEN__ */
