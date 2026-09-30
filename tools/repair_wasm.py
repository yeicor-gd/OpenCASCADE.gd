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

    needs_split = any(len(body) > max_size for body in func_bodies)
    if not needs_split:
        return

    print(f"Splitting large WebAssembly functions exceeding {max_size} bytes...")
    new_type_indices = list(type_indices)
    new_func_bodies = list(func_bodies)
    appended_funcs = []
    appended_types = []

    for i, body in enumerate(func_bodies):
        if len(body) <= max_size:
            continue

        print(f"Splitting function {i} (size: {len(body)} bytes)...")
        p = 0
        local_cnt, p = read_vu(body, p)
        assert local_cnt == 0, f"Function {i} has {local_cnt} locals; expected 0"

        stores = []
        while p < len(body):
            op = body[p]
            if op == 0x0B:
                p += 1
                break
            elif op == 0x23 or op == 0x41:
                _, p = read_vu(body, p + 1)
            elif op == 0x6A:
                p += 1
            elif op == 0x36:
                _, p = read_vu(body, p + 1)
                _, p = read_vu(body, p)
                stores.append(p)
            else:
                raise RuntimeError(f"Unhandled opcode 0x{op:02x} at offset {p} in large function")

        print(f"Found {len(stores)} store boundaries.")
        num_chunks = math.ceil(len(body) / target_chunk_size)
        chunk_size = len(stores) // num_chunks
        print(f"Splitting into {num_chunks} chunks (~{chunk_size} stores each)...")

        chunk_bodies = []
        cur_start = 1
        for c in range(num_chunks):
            if c == num_chunks - 1:
                cur_end = len(body) - 1
            else:
                store_idx = (c + 1) * chunk_size
                cur_end = stores[store_idx]
            chunk_data = b"\x00" + body[cur_start:cur_end] + b"\x0b"
            chunk_bodies.append(chunk_data)
            cur_start = cur_end

        orig_type = type_indices[i]
        caller_body = bytearray(b"\x00")
        for chunk_data in chunk_bodies:
            new_func_idx = import_func_count + len(new_func_bodies) + len(appended_funcs)
            appended_funcs.append(chunk_data)
            appended_types.append(orig_type)
            caller_body.append(0x10)
            caller_body.extend(encode_vu(new_func_idx))
        caller_body.append(0x0b)
        new_func_bodies[i] = bytes(caller_body)
        print(f"Replaced function {i} with trampoline of {len(new_func_bodies[i])} bytes.")

    new_func_bodies.extend(appended_funcs)
    new_type_indices.extend(appended_types)

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

    # Post-optimization function splitting (debug only):
    # In debug builds (-O0 --debuginfo) wasm-opt preserves the raw linker output,
    # so __wasm_apply_data_relocs stays monolithic (9.8MB+) and hits V8's
    # kV8MaxWasmFunctionSize limit (7.65MB). Release builds use -O2+ which
    # restructures code such that no single function remains that large.
    if is_debug:
        split_large_functions(output_path)

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
