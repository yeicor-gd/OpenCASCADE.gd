import math
import os
import os.path
import re
import shutil
import subprocess
import sys


def _find_wasm_opt():
    """Find wasm-opt, preferring the Emscripten SDK version over system."""
    candidates = []
    emsdk = os.environ.get("EMSDK")
    if emsdk:
        candidates.extend([
            os.path.join(emsdk, "upstream", "emscripten", "wasm-opt"),
            os.path.join(emsdk, "upstream", "bin", "wasm-opt"),
        ])
    user_home = os.path.expanduser("~")
    candidates.append(os.path.join(user_home, ".local", "emsdk", "upstream", "bin", "wasm-opt"))
    for candidate in candidates:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    which_candidate = shutil.which("wasm-opt")
    if which_candidate:
        return which_candidate
    return "wasm-opt"


WASM_OPT = _find_wasm_opt()


def get_error_offset(wasm_file):
    try:
        subprocess.run(
            [
                WASM_OPT,
                "--no-validation",
                "--enable-exception-handling",
                "--enable-bulk-memory",
                "-O0",
                wasm_file,
                "-o",
                os.devnull,
            ],
            stderr=subprocess.PIPE,
            stdout=subprocess.DEVNULL,
            check=True,
        )
        return None  # No errors
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.decode()
        print(stderr)
        for line in stderr.splitlines():
            all_non_zero_integers = re.findall(r"[1-9][0-9]*", line)
            if all_non_zero_integers:
                return int(all_non_zero_integers[0])
        raise RuntimeError(f"Could not parse offset from wasm-opt stderr:\n{stderr}")


def patch_wasm(wasm_bytes, error_offset):
    start = error_offset
    while start >= 0 and wasm_bytes[start] != 0x0E:
        start -= 1
    if start < 0:
        raise RuntimeError(
            f"Could not find br_table (0x0E) before the error offset at {error_offset}."
        )
    print(f"Fixing invalid instruction at bytes [{start}, {error_offset}]...")
    if error_offset + 1 - start > 30:
        raise RuntimeError(
            "Found br_table (0x0E) instruction is probably too long (maybe wasm is invalid for a different reason?)."
        )
    for i in range(start, error_offset + 1):
        wasm_bytes[i] = 0x00  # Replace with 'unreachable'
    return wasm_bytes


def encode_vu(val):
    res = bytearray()
    while True:
        b = val & 0x7F
        val >>= 7
        if val != 0:
            res.append(b | 0x80)
        else:
            res.append(b)
            break
    return bytes(res)


def read_vu(data, offset):
    res = 0
    shift = 0
    while True:
        b = data[offset]
        offset += 1
        res |= (b & 0x7F) << shift
        if (b & 0x80) == 0:
            break
        shift += 7
    return res, offset


def _get_reloc_target_indices(sections, import_func_count):
    """
    Return defined-function indices (0-based within the code section) that are
    named __wasm_apply_data_relocs / __wasm_apply_tls_relocs, or None when the
    name section is absent (caller falls back to trivial-pattern detection).
    See https://github.com/llvm/llvm-project/issues/55608 and
    https://github.com/llvm/llvm-project/pull/129007: only these trivial
    linker-generated functions are expected to exceed V8's
    kV8MaxWasmFunctionSize (7,654,321 bytes).
    """
    names = {}
    for sec_id, sec_data in sections:
        if sec_id != 0:
            continue
        try:
            n_len, p = read_vu(sec_data, 0)
            sec_name = sec_data[p : p + n_len].decode("utf-8")
        except Exception:
            continue
        if sec_name != "name":
            continue
        p += n_len
        try:
            while p < len(sec_data):
                sub_id = sec_data[p]
                p += 1
                sub_len, p = read_vu(sec_data, p)
                sub_end = p + sub_len
                if sub_id == 1:  # function names subsection
                    count, q = read_vu(sec_data, p)
                    for _ in range(count):
                        f_idx, q = read_vu(sec_data, q)
                        s_len, q = read_vu(sec_data, q)
                        f_name = sec_data[q : q + s_len].decode("utf-8", "replace")
                        q += s_len
                        names[f_idx] = f_name
                p = sub_end
        except Exception:
            continue
    if not names:
        return None
    targets = set()
    for f_idx, f_name in names.items():
        if f_name in ("__wasm_apply_data_relocs", "__wasm_apply_tls_relocs"):
            defined_idx = f_idx - import_func_count
            if defined_idx >= 0:
                targets.add(defined_idx)
    return targets


def _parse_trivial_reloc_body(body):
    """
    Validate that a function body is a trivial linker-generated relocation or
    data-initialization pattern (a flat sequence of stores with zero locals and
    balanced evaluation stack).
    Return ((header_len, store_end_offsets), None) on success, or (None, error_reason) on failure.
    """
    try:
        p = 0
        local_cnt, p = read_vu(body, p)
        if local_cnt != 0:
            return None, f"function has {local_cnt} local declarations (expected 0)"
        header_len = p
        stores = []
        stack_depth = 0
        while p < len(body):
            op = body[p]
            if op == 0x0B:  # end
                p += 1
                break
            elif op in (0x23, 0x41, 0x42):  # global.get, i32.const, i64.const
                _, p = read_vu(body, p + 1)
                stack_depth += 1
            elif op == 0x24:  # global.set
                _, p = read_vu(body, p + 1)
                stack_depth -= 1
            elif op == 0x43:  # f32.const (4 bytes)
                p += 5
                stack_depth += 1
            elif op == 0x44:  # f64.const (8 bytes)
                p += 9
                stack_depth += 1
            elif op in (
                0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70,  # i32 binary ops (add, sub, mul, div, rem)
                0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78,  # i32 bitwise / shift / rot
                0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82,  # i64 binary ops
                0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A,  # i64 bitwise / shift / rot
            ):
                p += 1
                stack_depth -= 1
            elif op in (
                0x50, 0x51,  # i32.eqz, i64.eqz
                0x67, 0x68, 0x69,  # i32.clz, i32.ctz, i32.popcnt
                0x79, 0x7A, 0x7B,  # i64.clz, i64.ctz, i64.popcnt
                0xA7, 0xAC, 0xAD,  # i32.wrap_i64, i64.extend_i32_u, i64.extend_i32_s
            ):
                p += 1  # unary ops: pops 1, pushes 1 -> depth unchanged
            elif op in (
                0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35
            ):  # load instructions: align (uleb128), offset (uleb128), pops 1, pushes 1 -> depth unchanged
                _, p = read_vu(body, p + 1)
                _, p = read_vu(body, p)
            elif op in (
                0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E
            ):  # store instructions: align (uleb128), offset (uleb128), pops 2, pushes 0
                _, p = read_vu(body, p + 1)
                _, p = read_vu(body, p)
                stack_depth -= 2
                if stack_depth == 0:
                    stores.append(p)
                elif stack_depth < 0:
                    return None, f"stack underflow ({stack_depth}) at offset {p}"
            elif op == 0x01:  # nop
                p += 1
            elif op == 0x1A:  # drop
                p += 1
                stack_depth -= 1
            else:
                return None, f"unhandled opcode 0x{op:02x} at offset {p}"

        if p != len(body):
            return None, f"trailing data ({len(body) - p} bytes) after end opcode"
        if stack_depth != 0:
            return None, f"unbalanced stack depth ({stack_depth}) at function end"
        return (header_len, stores), None
    except Exception as e:
        return None, f"exception parsing body: {e}"


def split_large_functions(wasm_path, max_size=4_000_000, target_chunk_size=3_000_000):
    """
    V8 enforces kV8MaxWasmFunctionSize (7,654,321 bytes).
    Large modules generate massive relocation functions (__wasm_apply_data_relocs)
    that exceed this limit. This pass splits functions > max_size into smaller chunks
    called by a lightweight trampoline.
    """
    with open(wasm_path, "rb") as f:
        wasm_bytes = f.read()

    if len(wasm_bytes) <= max_size:
        return

    offset = 8
    sections = []
    import_func_count = 0

    while offset < len(wasm_bytes):
        sec_id = wasm_bytes[offset]
        offset += 1
        sec_len, offset = read_vu(wasm_bytes, offset)
        sec_data = wasm_bytes[offset : offset + sec_len]
        offset += sec_len
        sections.append((sec_id, sec_data))
        if sec_id == 2:
            cnt, p = read_vu(sec_data, 0)
            for _ in range(cnt):
                ml, p = read_vu(sec_data, p); p += ml
                nl, p = read_vu(sec_data, p); p += nl
                kind = sec_data[p]; p += 1
                if kind == 0:
                    _, p = read_vu(sec_data, p)
                    import_func_count += 1
                elif kind == 1:
                    p += 1; flags = sec_data[p]; p += 1
                    _, p = read_vu(sec_data, p)
                    if flags & 1: _, p = read_vu(sec_data, p)
                elif kind == 2:
                    flags = sec_data[p]; p += 1
                    _, p = read_vu(sec_data, p)
                    if flags & 1: _, p = read_vu(sec_data, p)
                elif kind == 3:
                    p += 2
                elif kind == 4:
                    p += 1; _, p = read_vu(sec_data, p)

    sec3_matches = [i for i, (sid, _) in enumerate(sections) if sid == 3]
    sec10_matches = [i for i, (sid, _) in enumerate(sections) if sid == 10]
    if not sec3_matches or not sec10_matches:
        return

    sec3_idx = sec3_matches[0]
    sec10_idx = sec10_matches[0]

    sec3_data = sections[sec3_idx][1]
    func_count, p3 = read_vu(sec3_data, 0)
    type_indices = []
    for _ in range(func_count):
        t_idx, p3 = read_vu(sec3_data, p3)
        type_indices.append(t_idx)

    sec10_data = sections[sec10_idx][1]
    code_count, p10 = read_vu(sec10_data, 0)

    func_bodies = []
    for _ in range(code_count):
        body_len, p10 = read_vu(sec10_data, p10)
        func_bodies.append(sec10_data[p10 : p10 + body_len])
        p10 += body_len

    oversized = [i for i, b in enumerate(func_bodies) if len(b) > max_size]
    if not oversized:
        return

    named_targets = _get_reloc_target_indices(sections, import_func_count)

    print(f"Splitting large WebAssembly functions exceeding {max_size} bytes...")
    new_type_indices = list(type_indices)
    new_func_bodies = list(func_bodies)
    appended_funcs = []
    appended_types = []

    for i in oversized:
        body = func_bodies[i]
        parsed, parse_err = _parse_trivial_reloc_body(body)
        if parsed is None:
            if len(body) > 7_654_321:
                raise RuntimeError(
                    f"Function {i} (size: {len(body)} bytes) exceeds V8 maximum function size "
                    f"(7,654,321 bytes) but cannot be parsed for splitting: {parse_err}. "
                    "Leaving this function untouched will cause browser instantiate CompileError."
                )
            print(f"Skipping large function {i} (size: {len(body)} bytes): non-trivial body ({parse_err}), left as-is.")
            continue

        header_len, stores = parsed
        if not stores:
            if len(body) > 7_654_321:
                raise RuntimeError(
                    f"Function {i} (size: {len(body)} bytes) exceeds V8 maximum function size "
                    "(7,654,321 bytes) but has no store boundaries to split!"
                )
            print(f"Skipping large function {i} (size: {len(body)} bytes): no store boundaries found.")
            continue

        print(f"Splitting function {i} (size: {len(body)} bytes)...")
        print(f"Found {len(stores)} store boundaries.")
        num_chunks = max(1, math.ceil(len(body) / target_chunk_size))
        boundaries = sorted({(c + 1) * len(stores) // num_chunks for c in range(num_chunks - 1)})
        print(f"Splitting into {len(boundaries) + 1} chunks...")

        chunk_bodies = []
        cur_start = header_len
        for store_idx in boundaries:
            cur_end = stores[store_idx]
            chunk_data = b"\x00" + body[cur_start:cur_end] + b"\x0b"
            chunk_bodies.append(chunk_data)
            cur_start = cur_end
        chunk_data = b"\x00" + body[cur_start : len(body) - 1] + b"\x0b"
        chunk_bodies.append(chunk_data)

        orig_type = type_indices[i]
        caller_body = bytearray(b"\x00")
        for chunk_data in chunk_bodies:
            new_func_idx = import_func_count + len(new_func_bodies) + len(appended_funcs)
            appended_funcs.append(chunk_data)
            appended_types.append(orig_type)
            caller_body.append(0x10)
            caller_body.extend(encode_vu(new_func_idx))
        caller_body.append(0x0B)
        new_func_bodies[i] = bytes(caller_body)
        print(f"Replaced function {i} with trampoline of {len(new_func_bodies[i])} bytes.")

    if not appended_funcs:
        oversized_fatal = [(i, len(b)) for i, b in enumerate(func_bodies) if len(b) > 7_654_321]
        if oversized_fatal:
            raise RuntimeError(
                f"Cannot publish WebAssembly binary: functions exceed V8 size limit (7,654,321 bytes) "
                f"and were not split: {oversized_fatal}"
            )
        print("No functions needed splitting; leaving module unchanged.")
        return

    new_func_bodies.extend(appended_funcs)
    new_type_indices.extend(appended_types)

    # Verification pass: ensure NO function in new_func_bodies exceeds V8's hard limit
    for idx, fb in enumerate(new_func_bodies):
        if len(fb) > 7_654_321:
            raise RuntimeError(
                f"Function {idx} (size {len(fb)} bytes) still exceeds V8 maximum function size limit "
                f"(7,654,321 bytes) after splitting in {wasm_path}!"
            )

    # Re-encode Section 3
    new_sec3_data = bytearray()
    new_sec3_data.extend(encode_vu(len(new_type_indices)))
    for t in new_type_indices:
        new_sec3_data.extend(encode_vu(t))
    sections[sec3_idx] = (3, bytes(new_sec3_data))

    # Re-encode Section 10
    new_sec10_data = bytearray()
    new_sec10_data.extend(encode_vu(len(new_func_bodies)))
    for fb in new_func_bodies:
        new_sec10_data.extend(encode_vu(len(fb)))
        new_sec10_data.extend(fb)
    sections[sec10_idx] = (10, bytes(new_sec10_data))

    out = bytearray(wasm_bytes[:8])
    for sid, sdata in sections:
        out.append(sid)
        out.extend(encode_vu(len(sdata)))
        out.extend(sdata)

    with open(wasm_path, "wb") as f:
        f.write(out)
    print(f"Successfully split large functions in {wasm_path}")


def repair_and_optimize_wasm(input_path, output_path):
    print(f"Copying and repairing: {input_path}")

    if not os.path.isfile(input_path):
        raise FileNotFoundError(f"Input file not found: {input_path}")

    with open(input_path, "rb") as f:
        wasm_bytes = bytearray(f.read())

    fixed_path = input_path + ".fixed.wasm"

    while True:
        with open(fixed_path, "wb") as f:
            f.write(wasm_bytes)

        print("Looking for (more) errors...")
        offset = get_error_offset(fixed_path)
        if offset is None:
            break  # All errors fixed

        wasm_bytes = patch_wasm(wasm_bytes, offset)

    is_debug = os.environ.get("DEBUG", "").lower() in {"1", "on", "true", "yes"}
    opt_level = os.environ.get("WASM_OPT_LEVEL", "-O2")
    wasm_opt_args = (
        ["-O0", "--debuginfo", "--remove-unused-module-elements"]
        if is_debug
        else [opt_level]
    )

    print("Patching complete. Starting optimization (" + str(wasm_opt_args) + ")...")

    subprocess.run(
        [
            WASM_OPT,
            "--no-validation",
            "--enable-exception-handling",
            "--enable-bulk-memory",
            "--post-emscripten",
        ]
        + wasm_opt_args
        + [fixed_path, "-o", output_path],
        check=True,
    )

    # Post-optimization function splitting:
    # __wasm_apply_data_relocs is generated by wasm-ld as a flat sequence of
    # i32.store instructions (one per relocated data word). wasm-opt has no
    # reason to split it regardless of optimization level, so it stays at
    # ~9.8MB for OCCT's large static data tables. V8 enforces a hard
    # kV8MaxWasmFunctionSize limit of 7,654,321 bytes, causing an instantiation
    # CompileError. This pass chunks any function > 4MB into ~3MB pieces called
    # by a small trampoline, for both debug and release builds.
    split_large_functions(output_path)

    # Verification with Node.js V8 WebAssembly engine if available
    if shutil.which("node"):
        print(f"Verifying {output_path} with Node.js V8 WebAssembly engine...")
        res = subprocess.run(
            [
                "node",
                "-e",
                f"const fs = require('fs'); const bytes = fs.readFileSync({repr(output_path)}); "
                "new WebAssembly.Module(bytes); console.log('V8 WebAssembly.Module compilation successful!');",
            ],
            capture_output=True,
            text=True,
        )
        if res.returncode != 0:
            raise RuntimeError(
                f"V8 WebAssembly compilation verification failed on {output_path}:\n"
                f"{res.stderr}\n{res.stdout}"
            )
        print("V8 WebAssembly verification succeeded!")

    # Copy map file if it exists
    possible_map_file = input_path + ".map"
    if os.path.isfile(possible_map_file):
        print("Also copying map file with debug information")
        shutil.copy(possible_map_file, output_path + ".map")

    os.remove(fixed_path)
    print(f"Optimized WebAssembly written to: {output_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python repair_wasm.py <input_dir> <output_dir>")
        sys.exit(1)

    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    os.makedirs(output_dir, exist_ok=True)

    input_files = [f for f in os.listdir(input_dir) if f.endswith(".so")]
    if len(input_files) != 1:
        print(
            f"No so file or too many so/wasm files found ({input_files}) in input directory: {input_dir} (all files: {os.listdir(input_dir)})"
        )
        sys.exit(1)

    input_filename = input_files[0]
    input_path = os.path.join(input_dir, input_filename)
    output_path = os.path.join(output_dir, input_filename)

    repair_and_optimize_wasm(input_path, output_path)
