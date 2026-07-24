import os
import os.path
import re
import shutil
import subprocess
import sys


def _find_wasm_opt():
    """Find wasm-opt, preferring the Emscripten SDK version over system."""
    emsdk = os.environ.get("EMSDK")
    if emsdk:
        candidate = os.path.join(emsdk, "upstream", "emscripten", "wasm-opt")
        if os.path.isfile(candidate):
            return candidate
        candidate = os.path.join(emsdk, "upstream", "bin", "wasm-opt")
        if os.path.isfile(candidate):
            return candidate
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
    wasm_opt_args = (
        ["-O0", "--debuginfo"]
        if is_debug
        else ["-O4"]
        if os.environ.get("CI", "").lower() in {"1", "on", "true", "yes"}
        else ["-O1"]
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
