#!/usr/bin/env bash
# Build custom Godot web export templates for Web with wasm-native C++ exceptions.
#
# The default Godot web export templates are built with exceptions disabled
# (disable_exceptions=yes).  Our GDExtension SIDE_MODULE is built with
# -fwasm-exceptions (wasm-native C++ EH) which requires:
#
#   1. The __cpp_exception WebAssembly.Tag  (emscripten's loadWebAssemblyModule
#      proxy does not serve Tag objects, so we patch godot.js to provide it).
#
#   2. The __wasm_lpad_context symbol from the wasm-eh runtime, which lives
#      in the main module when it is also built with -fwasm-exceptions.
#
# This script builds custom Godot web export templates with:
#   - disable_exceptions=no  (enable C++ exceptions)
#   - -fwasm-exceptions      (wasm-native EH, matching our SIDE_MODULE)
#
# The JS glue patch is a known emscripten limitation (loadWebAssemblyModule
# cannot resolve WebAssembly.Tag imports) and is stable across versions.
#
# By default, builds all 2 combinations: debug/release (threads only).
# Use flags to restrict to specific variants.
#
# When --editor is used with --mode, the output zip is named accordingly:
#   --editor --mode=debug   -> web_editor_debug.zip
#   --editor --mode=release -> web_editor_release.zip
#   --editor (no mode)      -> web_editor.zip
#
# Usage:
#   ./tools/build_godot_web_templates.sh [OPTIONS] [OUTPUT_DIR]
#
# Options:
#   --mode=debug    Build only debug variant (default: both)
#   --mode=release  Build only release variant (default: both)
#   --editor        Build the editor instead of export templates
#   --clean         Clean build (remove previous build directory)
#   --version TAG   Godot version tag to build (default: auto-detect latest stable)
#   OUTPUT_DIR      Where to place the output template zips (default: demo/templates)
#
# Prerequisites:
#   - Emscripten SDK installed and activated (emcc in PATH)
#   - Python 3.9+
#   - SCons 4.4+
#   - Internet connection (for downloading Godot source)
#   - jq (for version detection from GitHub API)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Defaults: build debug+release
BUILD_DEBUG="yes"
BUILD_RELEASE="yes"
BUILD_EDITOR=0
CLEAN=0
OUTPUT_DIR="${PROJECT_DIR}/demo/templates"
GODOT_VERSION=""  # Empty = auto-detect

# Use wasm-native C++ exceptions for the main module so it matches our
# SIDE_MODULE (built with -fwasm-exceptions).  This ensures the main module
# contains __wasm_lpad_context and other wasm-eh runtime symbols that the
# side module imports via GOT.
#
# Export the JS setjmp/longjmp runtime methods so the side module can reach
# them if any library (e.g. OCCT) uses setjmp-style control flow.  Note: with
# -fwasm-exceptions the compiler emits wasm-native setjmp/longjmp, so the wasm
# symbols _setjmp/_longjmp may not exist at all — exporting those via
# EXPORTED_FUNCTIONS would be an error, hence the EXPORTED_RUNTIME_METHODS.
EM_LINKFLAGS="-fwasm-exceptions -sEXPORTED_RUNTIME_METHODS=setjmp,longjmp"
export EMCC_CFLAGS="${EMCC_CFLAGS:-} -fwasm-exceptions"
export EMCC_CXXFLAGS="${EMCC_CXXFLAGS:-} -fwasm-exceptions"
export EM_LINKFLAGS

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode=debug)
            BUILD_DEBUG="yes"
            BUILD_RELEASE="no"
            shift
            ;;
        --mode=release)
            BUILD_DEBUG="no"
            BUILD_RELEASE="yes"
            shift
            ;;
        --editor)
            BUILD_EDITOR=1
            shift
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --version)
            GODOT_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [OUTPUT_DIR]"
            echo ""
            echo "Build custom Godot web export templates with C++ exceptions enabled."
            echo "Threads-only (nothreads is not supported due to OCCT thread dependencies)."
            echo ""
            echo "Options:"
            echo "  --mode=debug    Build only debug variant"
            echo "  --mode=release  Build only release variant"
            echo "  --editor        Build the editor instead of export templates"
            echo "                  Output zip is named web_editor[_mode].zip"
            echo "  --clean         Clean build (remove previous build directory)"
            echo "  --version TAG   Godot version tag to build (default: auto-detect latest stable)"
            echo "  OUTPUT_DIR      Where to place the output (default: demo/templates)"
            exit 0
            ;;
        *)
            OUTPUT_DIR="$1"
            shift
            ;;
    esac
done

# Auto-detect latest stable Godot version (same logic as .github/workflows/main.yml)
detect_godot_version() {
    local compat_min
    compat_min=$(grep 'compatibility_minimum' "${PROJECT_DIR}/demo/addons/"*"/gdext.gdextension" | sed 's/.*= "\(.*\)"/\1/')

    local supported_json
    supported_json=$(grep '^supported_api_versions' "${PROJECT_DIR}/godot-cpp/tools/godotcpp.py" | sed 's/.*= //' | head -n 1)

    if ! echo "$supported_json" | grep -q "\"$compat_min\""; then
        echo "Error: compatibility_minimum=$compat_min is not in godot-cpp supported_api_versions" >&2
        exit 1
    fi

    # Get all supported versions >= compat_min
    local versions
    versions=$(echo "$supported_json" | jq -r '.[]')

    local latest_tag=""
    for version in $versions; do
        # Skip versions below compat_min
        if [[ "$(printf '%s\n' "$version" "$compat_min" | sort -V | head -n1)" != "$compat_min" ]]; then
            continue
        fi
        # Query GitHub API for latest release matching this major.minor prefix
        local tag
        tag=$(curl -s "https://api.github.com/repos/godotengine/godot/releases" \
            | jq -r ".[] | select(.tag_name | startswith(\"$version.\")) | .tag_name" \
            | sort -V | tail -1)
        if [ -n "$tag" ]; then
            latest_tag="$tag"
        fi
    done

    if [ -z "$latest_tag" ]; then
        echo "Error: Could not detect latest Godot version" >&2
        exit 1
    fi

    echo "$latest_tag"
}

# Check prerequisites
check_prerequisites() {
    local missing=0

    if ! command -v emcc &>/dev/null; then
        echo "Error: emcc not found. Please activate the Emscripten SDK first."
        echo "  source /path/to/emsdk/emsdk_env.sh"
        missing=1
    fi

    if ! command -v scons &>/dev/null; then
        echo "Error: scons not found. Install with: pip install scons"
        missing=1
    fi

    if ! command -v python3 &>/dev/null; then
        echo "Error: python3 not found."
        missing=1
    fi

    if ! command -v jq &>/dev/null; then
        echo "Error: jq not found. Install with: sudo apt install jq"
        missing=1
    fi

    if [ $missing -ne 0 ]; then
        exit 1
    fi

    # Validate Emscripten version matches what godot-cpp expects
    local expected_em_version
    expected_em_version=$(sed -n '/em-version:/,/default:/{s/.*default: *//p}' "${PROJECT_DIR}/godot-cpp/.github/actions/setup-godot-cpp/action.yml" | tr -d '[:space:]')
    local actual_em_version
    actual_em_version=$(emcc --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+')
    if [ -z "$expected_em_version" ]; then
        echo "Warning: Could not read expected Emscripten version from godot-cpp" >&2
    elif [ "$actual_em_version" != "$expected_em_version" ]; then
        echo "Error: Emscripten version mismatch." >&2
        echo "  Expected: ${expected_em_version} (from godot-cpp)" >&2
        echo "  Actual:   ${actual_em_version}" >&2
        echo "  Install the correct version: emsdk install ${expected_em_version} && emsdk activate ${expected_em_version}" >&2
        exit 1
    fi

    echo "Prerequisites OK"
    echo "  emcc: $(emcc --version | head -1)"
    echo "  em-version: ${actual_em_version} (matches godot-cpp: ${expected_em_version})"
    echo "  scons: $(scons --version | head -1)"
}

# Download and extract Godot source
setup_godot_source() {
    local build_dir="${PROJECT_DIR}/build"
    local godot_dir="${build_dir}/godot-${GODOT_VERSION}"

    if [ -d "$godot_dir" ]; then
        echo "Godot source already exists at: $godot_dir"
        if [ $CLEAN -eq 1 ]; then
            echo "Cleaning previous build..."
            rm -rf "$godot_dir"
        else
            return 0
        fi
    fi

    echo "Downloading Godot ${GODOT_VERSION} sources..."
    mkdir -p "$build_dir"
    cd "$build_dir"

    git clone --depth 1 --branch "${GODOT_VERSION}" \
        https://github.com/godotengine/godot.git "godot-${GODOT_VERSION}"

    cd "$PROJECT_DIR"
    echo "Godot source ready at: $godot_dir"
}

# Build a single variant (threads only)
build_one_variant() {
    local target="$1"   # template_debug, template_release, or editor

    local godot_dir="${PROJECT_DIR}/build/godot-${GODOT_VERSION}"

    echo "--- Building ${target} (threads=yes) ---"

    cd "$godot_dir"
    local scons_args=(
        -j"$(nproc)"
        platform=web
        target="${target}"
        dlink_enabled=yes
        threads=yes
        production=yes
        disable_exceptions=no
    )
    if [[ -n "${EM_LINKFLAGS}" ]]; then
        scons_args+=(linkflags="${EM_LINKFLAGS}")
    fi
    # Force all standard libraries (libc++, libc++abi, etc.) into the main
    # module so that side modules (GDExtensions) can import their symbols at
    # runtime. Without this, symbols like std::__2::__hash_memory are missing.
    # See: https://emscripten.org/docs/compiling/Dynamic-Linking.html#system-libraries
    EMCC_FORCE_STDLIBS=1 scons "${scons_args[@]}"

    cd "$PROJECT_DIR"
}

# Patch godot.js inside a template zip to provide the __cpp_exception tag.
#
# Our SIDE_MODULE is built with -fwasm-exceptions (wasm-native C++ EH) which
# generates an import for the __cpp_exception tag from the "env" module.
# Emscripten's loadWebAssemblyModule proxy does NOT serve WebAssembly.Tag
# objects, so the tag import fails at instantiation time.
#
# This function patches the proxyHandler in godot.js to detect __cpp_exception
# tag look-ups and return a reusable WebAssembly.Tag instance.
patch_template_js() {
    # Use an absolute path: the re-pack below runs from a temp dir, and zip
    # update mode creates a sibling output file next to the archive.
    local zip_path
    zip_path="$(realpath "$1")"

    local _tmp_dir
    _tmp_dir=$(mktemp -d)

    # Editor zips use godot.editor.js, template zips use godot.js
    local js_name="godot.js"
    unzip -l "$zip_path" | grep -q 'godot\.editor\.js' && js_name="godot.editor.js"
    unzip -oq "$zip_path" "$js_name" -d "$_tmp_dir"

    # Editor builds use preloadedWasmModules and an older Emscripten that needs
    # extra patches. Export templates already handle both code paths correctly.
    local is_editor=0
    [ "$js_name" = "godot.editor.js" ] && is_editor=1

    local js_file="${_tmp_dir}/${js_name}"
    local sentinel='case"__cpp_exception":'

    local py_rc=0
    python3 -u - "$js_file" "$is_editor" << 'PYEOF' || py_rc=$?
import sys

path = sys.argv[1]
is_editor = int(sys.argv[2])
with open(path) as f:
    content = f.read()

failed = False

# Patch 1: proxyHandler – serve the __cpp_exception WebAssembly.Tag
old1 = 'case"__memory_base":return memoryBase;case"__table_base":return tableBase}'
new1 = 'case"__memory_base":return memoryBase;case"__table_base":return tableBase;case"__cpp_exception":if(!globalThis.__cpp_exception_tag)globalThis.__cpp_exception_tag=new WebAssembly.Tag({parameters:["i32"]});return globalThis.__cpp_exception_tag}'
if old1 not in content:
    print("Warning: proxyHandler pattern not found", flush=True)
    failed = True
elif new1 in content:
    print("  Patch 1 (tag) already applied", flush=True)
else:
    content = content.replace(old1, new1, 1)
    print("  Applied patch 1 (__cpp_exception tag)", flush=True)

# Patch 2: resolveGlobalSymbol – fall through to wasmExports
old2 = 'var resolveGlobalSymbol=(symName,direct=false)=>{var sym;if(isSymbolDefined(symName)){sym=wasmImports[symName]}return{sym,name:symName}};'
new2 = 'var resolveGlobalSymbol=(symName,direct=false)=>{var sym;if(isSymbolDefined(symName)){sym=wasmImports[symName]}else if(typeof wasmExports!=="undefined"){var e=wasmExports[symName];if(typeof e==="function")sym=e;else if(e&&typeof e.value!=="undefined")sym=+e.value}return{sym,name:symName}};'
if old2 not in content:
    print("Warning: resolveGlobalSymbol pattern not found", flush=True)
    failed = True
elif new2 in content:
    print("  Patch 2 (resolveGlobalSymbol) already applied", flush=True)
else:
    content = content.replace(old2, new2, 1)
    print("  Applied patch 2 (resolveGlobalSymbol)", flush=True)

# Patch 3: findLibraryFS – add JS fallback to search Emscripten FS
old3 = 'return withStackSave(()=>{var bufSize=2*255+2;var buf=stackAlloc(bufSize);var rpathC=stringToUTF8OnStack(rpathResolved.join(":"));var libNameC=stringToUTF8OnStack(libName);var resLibNameC=__emscripten_find_dylib(buf,rpathC,libNameC,bufSize);return resLibNameC?UTF8ToString(resLibNameC):undefined})};'
new3 = 'var _flr=withStackSave(()=>{var bufSize=2*255+2;var buf=stackAlloc(bufSize);var rpathC=stringToUTF8OnStack(rpathResolved.join(":"));var libNameC=stringToUTF8OnStack(libName);var resLibNameC=__emscripten_find_dylib(buf,rpathC,libNameC,bufSize);return resLibNameC?UTF8ToString(resLibNameC):undefined});if(_flr)return _flr;try{_fl=FS.cwd();FS.lookupPath(_fl+"/"+libName);return _fl+"/"+libName}catch(e){}try{FS.lookupPath("/"+libName);return "/"+libName}catch(e){}return undefined};'
if old3 not in content:
    print("Warning: findLibraryFS pattern not found", flush=True)
    failed = True
elif new3 in content:
    print("  Patch 3 (findLibraryFS fallback) already applied", flush=True)
else:
    content = content.replace(old3, new3, 1)
    print("  Applied patch 3 (findLibraryFS fallback)", flush=True)

# Patch 4: loadLibData – check global __preloadedWasmModules registry.
# Editor-only: export templates already handle sharedModules lookups correctly.
if is_editor:
    old4 = 'function loadLibData(){var sharedMod=sharedModules[libName];'
    new4 = 'function loadLibData(){var sharedMod=(typeof __preloadedWasmModules!=="undefined"&&__preloadedWasmModules[libName])||sharedModules[libName];'
    if old4 not in content:
        print("Warning: loadLibData pattern not found", flush=True)
        failed = True
    elif new4 in content:
        print("  Patch 4 (preloadedWasmModules) already applied", flush=True)
    else:
        content = content.replace(old4, new4, 1)
        print("  Applied patch 4 (preloadedWasmModules)", flush=True)

with open(path, 'w') as f:
    f.write(content)

if failed:
    sys.exit(1)
PYEOF

    if [ $py_rc -ne 0 ]; then
        echo "  Error: Python patching script failed (exit code $py_rc)" >&2
        rm -rf "$_tmp_dir"
        return 1
    fi

    # Verify all patches were applied
    local verify_failed=0
    if ! grep -q "$sentinel" "$js_file"; then
        echo "  Warning: tag pattern not found after patching" >&2
        verify_failed=1
    fi
    if ! grep -q 'wasmExports\[symName\]' "$js_file"; then
        echo "  Warning: resolveGlobalSymbol pattern not found after patching" >&2
        verify_failed=1
    fi
    if ! grep -q '_flr=' "$js_file"; then
        echo "  Warning: findLibraryFS fallback not found after patching" >&2
        verify_failed=1
    fi
    # Only verify editor-specific patches on editor zips
    if [ "$is_editor" -eq 1 ]; then
        if ! grep -q '__preloadedWasmModules' "$js_file"; then
            echo "  Warning: preloadedWasmModules not found after patching" >&2
            verify_failed=1
        fi
    fi
    if [ $verify_failed -ne 0 ]; then
        rm -rf "$_tmp_dir"
        return 1
    fi

    # Re-pack into the zip using Python (zip command may not be installed)
    local zip_rc=0
    python3 -u - "$zip_path" "$_tmp_dir/$js_name" "$js_name" << 'PYEOF' || zip_rc=$?
import sys, zipfile, os

zip_path, patched_file, arcname = sys.argv[1], sys.argv[2], sys.argv[3]
with open(patched_file, 'rb') as f:
    data = f.read()
tmp = zip_path + '.tmp'
with zipfile.ZipFile(zip_path, 'r') as zin:
    with zipfile.ZipFile(tmp, 'w', compression=zin.compression) as zout:
        for item in zin.infolist():
            if item.filename == arcname:
                zout.writestr(item, data)
            else:
                zout.writestr(item, zin.read(item.filename))
os.replace(tmp, zip_path)
PYEOF
    rm -rf "$_tmp_dir"
    if [ $zip_rc -ne 0 ]; then
        echo "  Error: zip repack failed (exit code $zip_rc)" >&2
        return 1
    fi
    local patches_desc="tag + resolveGlobalSymbol + findLibraryFS"
    [ "$is_editor" -eq 1 ] && patches_desc="${patches_desc} + preloadedWasm"
    echo "  Patched $(basename "$zip_path") (${patches_desc})"
}

# Install a template zip to the output dir
install_template_zip() {
    local target="$1"   # template_debug or template_release

    local godot_dir="${PROJECT_DIR}/build/godot-${GODOT_VERSION}"

    local zip_file="${godot_dir}/bin/godot.web.${target}.wasm32.dlink.zip"
    [ ! -f "$zip_file" ] && zip_file="${godot_dir}/bin/godot.web.${target}.wasm32.pthreads.dlink.zip"
    [ ! -f "$zip_file" ] && zip_file="${godot_dir}/bin/godot.web.${target}.wasm32.pthreads.zip"
    if [ ! -f "$zip_file" ]; then
        echo "Error: Could not find built zip for ${target} (threads=yes)" >&2
        ls "${godot_dir}/bin/"*.zip 2>/dev/null || true
        exit 1
    fi

    local mode_name
    [ "$target" = "template_debug" ] && mode_name="debug" || mode_name="release"

    local dest_dir="${OUTPUT_DIR}/threads"
    mkdir -p "$dest_dir"
    cp "$zip_file" "${dest_dir}/web_${mode_name}.zip"
    echo "Installed: ${dest_dir}/web_${mode_name}.zip"

    # Patch godot.js inside the zip for __cpp_exception tag support
    patch_template_js "${dest_dir}/web_${mode_name}.zip"
}

# Install editor binary to the output dir
#   $1 = mode_name: "debug", "release", or "" (unnamed)
install_editor_binary() {
    local mode_name="$1"

    local godot_dir="${PROJECT_DIR}/build/godot-${GODOT_VERSION}"

    local zip_file="${godot_dir}/bin/godot.web.editor.wasm32.dlink.zip"
    [ ! -f "$zip_file" ] && zip_file="${godot_dir}/bin/godot.web.editor.wasm32.pthreads.dlink.zip"
    [ ! -f "$zip_file" ] && zip_file="${godot_dir}/bin/godot.web.editor.wasm32.pthreads.zip"
    if [ ! -f "$zip_file" ]; then
        echo "Error: Could not find built editor zip (threads=yes)" >&2
        ls "${godot_dir}/bin/"*.zip 2>/dev/null || true
        exit 1
    fi

    local dest_dir="${OUTPUT_DIR}/editor/threads"
    mkdir -p "$dest_dir"

    local dest_name="web_editor"
    [ -n "$mode_name" ] && dest_name="${dest_name}_${mode_name}"
    cp "$zip_file" "${dest_dir}/${dest_name}.zip"
    echo "Installed: ${dest_dir}/${dest_name}.zip"

    # Patch the editor JS inside the zip for __cpp_exception tag support
    patch_template_js "${dest_dir}/${dest_name}.zip"
}

# Build all selected variants
build_web() {
    local godot_dir="${PROJECT_DIR}/build/godot-${GODOT_VERSION}"

    if [ ! -d "$godot_dir" ]; then
        echo "Error: Godot source not found at $godot_dir"
        exit 1
    fi

    local targets=()
    [ "$BUILD_DEBUG" = "yes" ] && targets+=("template_debug")
    [ "$BUILD_RELEASE" = "yes" ] && targets+=("template_release")

    if [ $BUILD_EDITOR -eq 1 ]; then
        echo ""
        echo "=== Building Godot Web editor ==="
        echo "  Version: ${GODOT_VERSION}"
        echo "  Exceptions: enabled (disable_exceptions=no)"
        echo "  Threads: yes"
        echo ""

        build_one_variant "editor"

        local editor_mode_name=""
        if [ "$BUILD_DEBUG" = "yes" ] && [ "$BUILD_RELEASE" = "yes" ]; then
            editor_mode_name=""
        elif [ "$BUILD_DEBUG" = "yes" ]; then
            editor_mode_name="debug"
        else
            editor_mode_name="release"
        fi
        install_editor_binary "$editor_mode_name"
    else
        echo ""
        echo "=== Building Godot Web export templates ==="
        echo "  Version: ${GODOT_VERSION}"
        echo "  Exceptions: enabled (disable_exceptions=no)"
        echo "  Variants: debug=${BUILD_DEBUG} release=${BUILD_RELEASE} threads=yes"
        echo ""

        for target in "${targets[@]}"; do
            build_one_variant "$target"
            install_template_zip "$target"
        done
    fi

    cd "$PROJECT_DIR"
}

# Main
main() {
    # Auto-detect version if not specified
    if [ -z "$GODOT_VERSION" ]; then
        echo "Auto-detecting latest stable Godot version..."
        GODOT_VERSION=$(detect_godot_version)
        echo "Detected: ${GODOT_VERSION}"
    fi

    echo ""
    echo "=== Building Custom Godot Web Build ==="
    echo "  Godot version: ${GODOT_VERSION}"
    echo "  Output: ${OUTPUT_DIR}"
    echo ""

    check_prerequisites
    setup_godot_source
    build_web

    echo ""
    echo "=== Build complete ==="
    find "${OUTPUT_DIR}" -name "*.zip" -exec ls -la {} \;

    echo ""
    echo "Done! Output installed to: ${OUTPUT_DIR}"
    if [ $BUILD_EDITOR -eq 1 ]; then
        local editor_mode_name=""
        if [ "$BUILD_DEBUG" = "yes" ] && [ "$BUILD_RELEASE" = "yes" ]; then
            editor_mode_name=""
        elif [ "$BUILD_DEBUG" = "yes" ]; then
            editor_mode_name="_debug"
        else
            editor_mode_name="_release"
        fi
        echo "  editor/threads/web_editor${editor_mode_name}.zip"
    else
        echo "  threads/web_debug.zip, threads/web_release.zip"
    fi
}

main "$@"
