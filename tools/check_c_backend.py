#!/usr/bin/env python3
"""Compile/run probes only. Never installs tools, edits generated C, or links firmware."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import struct
import subprocess
import sys

ABI_NAMES = ["char", "signed_char", "unsigned_char", "short", "unsigned_short",
             "int", "unsigned_int", "long", "unsigned_long", "long_long", "unsigned_long_long",
             "float", "double", "long_double", "pointer", "size_t", "ptrdiff_t", "intptr_t", "uintptr_t",
             "int8_t", "uint8_t", "int16_t", "uint16_t", "int32_t", "uint32_t", "int64_t", "uint64_t"]


def expected_abi(path):
    text = path.read_text()
    match = re.search(r"const [^;\n]*mimoc_abi_expectations[^;\n]* = \{\{(.*?)\}\};", text, re.S)
    if not match:
        raise RuntimeError("Cannot read compiler-generated ABI expectation constant")
    values = [int(v) for v in re.findall(r"UINT32_C\((\d+)\)", match.group(1))]
    if len(values) != 2 * len(ABI_NAMES):
        raise RuntimeError("Unexpected ABI expectation table length")
    return dict(zip(ABI_NAMES, [values[i:i+2] for i in range(0, len(values), 2)]))


def expected_mixed_layout(path):
    match = re.search(r"const [^;\n]*mimoc_abi_mixed_layout[^;\n]* = \{\{(.*?)\}\};", path.read_text(), re.S)
    if not match:
        raise RuntimeError("Cannot read compiler-generated aggregate ABI constant")
    values = [int(v) for v in re.findall(r"UINT32_C\((\d+)\)", match.group(1))]
    if len(values) != 6:
        raise RuntimeError("Unexpected aggregate ABI table length")
    return values


def command(argv, log, env=None):
    argv = [str(x) for x in argv]
    print("$ " + shlex.join(argv), flush=True)
    result = subprocess.run(argv, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout)
    if result.returncode:
        errors = [line for line in result.stdout.splitlines() if "error:" in line or "Error " in line]
        print("\n".join(errors[:8]) or "\n".join(result.stdout.splitlines()[-12:]))
        print(f"Full compiler output: {log}")
    return result


def metadata(args, out):
    source = args.generated.read_bytes()
    data = {"source": str(args.generated), "generated_bytes": len(source),
            "generated_lines": len(source.splitlines()), "sha256": hashlib.sha256(source).hexdigest()}
    data["zig_version"] = command([args.zig, "version"], out / "zig-version.txt").stdout.strip()
    command([args.zig, "env"], out / "zig-env.txt")
    if data["zig_version"] != "0.17.0":
        raise RuntimeError("This probe requires upstream Zig exactly 0.17.0")
    compiler = Path(shutil.which(args.zig) or args.zig).resolve()
    data["zig_binary_sha256"] = hashlib.sha256(compiler.read_bytes()).hexdigest()
    for name, relative in [("zig_target_source_sha256", "std/Target.zig"), ("zig_h_sha256", "zig.h")]:
        data[name] = hashlib.sha256((args.zig_lib / relative).read_bytes()).hexdigest()
    return data


def host(args, out, data):
    cc = shlex.split(args.cc or os.environ.get("CC", "clang" if sys.platform == "darwin" else "cc"))
    data["compiler"] = command(cc + ["--version"], out / "host-compiler.txt").stdout
    obj = out / "generated.o"
    # Rename only public verification symbols so both identical implementations can coexist.
    flags = ["-std=c11", "-O2", "-Wall", "-Wextra", "-I", str(args.zig_lib)]
    rename = ["-Dmimoc_ui_smoke_" + name + "=c_mimoc_ui_smoke_" + name for name in ["init", "step", "render"]]
    build = command(cc + flags + rename + ["-c", args.generated, "-o", obj], out / "host-generated.log")
    data["generated_warning_count"] = len(re.findall(r"warning:", build.stdout))
    data["warning_categories"] = sorted(set(re.findall(r"\[(-W[^]]+)\]", build.stdout)))
    if build.returncode:
        data["stage_a"] = "FAIL"
        return build.returncode
    exe = out / "compare"
    link = command(cc + ["-std=c11", "-O2", "-Wall", "-Wextra", "-Werror", args.driver, args.native, obj, "-o", exe], out / "host-link.log")
    if link.returncode:
        data["stage_a"] = "FAIL"
        return link.returncode
    data["host_executable_bytes"] = exe.stat().st_size
    data["host_object_bytes"] = obj.stat().st_size
    check = command([exe], out / "equivalence.log")
    print(check.stdout.strip())
    data["equivalence"] = check.stdout.strip()
    data["stage_a"] = "PASS" if check.returncode == 0 else "FAIL"
    print(f"Generated C: {data['generated_bytes']} bytes, {data['generated_lines']} lines; warnings={data['generated_warning_count']}; executable={data['host_executable_bytes']} bytes")
    return check.returncode


def idf_version(path):
    version = path / "version.txt"
    return tuple(int(n) for n in re.findall(r"\d+", version.read_text())[:3]) if version.exists() else (0,)


def detect_tool_pairs(args):
    home = Path.home()
    explicit_idf = args.idf or os.environ.get("IDF_PATH")
    idfs = [Path(explicit_idf)] if explicit_idf else [home / "esp/esp-idf", *sorted((home / ".platformio/packages").glob("framework-espidf*"), key=idf_version, reverse=True)]
    explicit_gcc = args.gcc or os.environ.get("XTENSA_GCC")
    if explicit_gcc:
        found = shutil.which(explicit_gcc) or explicit_gcc
        compilers = [Path(found)]
    else:
        compilers = []
        # Prefer IDF's own managed tools, then already-installed official packages.
        esp_tools = Path(os.environ.get("IDF_TOOLS_PATH", str(home / ".espressif"))) / "tools"
        compilers.extend(sorted(esp_tools.glob("xtensa-esp-elf/*/xtensa-esp-elf/bin/xtensa-esp-elf-gcc"), reverse=True))
        if shutil.which("xtensa-esp-elf-gcc"):
            compilers.append(Path(shutil.which("xtensa-esp-elf-gcc")))
        compilers.extend(sorted((home / ".platformio/packages").glob("toolchain-xtensa-esp-elf*/bin/xtensa-esp-elf-gcc"), reverse=True))
    pairs = []
    for idf in idfs:
        tools_json = idf / "tools/tools.json"
        toolchain = idf / "tools/cmake/toolchain-esp32s3.cmake"
        if not tools_json.exists() or not toolchain.exists():
            continue
        records = json.loads(tools_json.read_text())["tools"]
        releases = [v for tool in records if tool["name"] == "xtensa-esp-elf" for v in tool["versions"]]
        allowed = {v["name"] for v in releases if any(isinstance(item, dict) and "github.com/espressif/crosstool-NG/" in item.get("url", "") for item in v.values())}
        for gcc in compilers:
            if not gcc.is_file():
                continue
            version = subprocess.run([str(gcc), "--version"], capture_output=True, text=True)
            if version.returncode:
                continue
            vendor = re.search(r"crosstool-NG (esp-[^) ]+)", version.stdout)
            if not vendor or vendor.group(1) not in allowed:
                continue
            s3 = gcc.parent / "xtensa-esp32s3-elf-gcc"
            if s3.is_file():
                pairs.append((idf.resolve(), gcc.resolve(), s3, version.stdout))
                break
    if not pairs:
        raise RuntimeError("Stage B blocked: official ESP-IDF Xtensa GCC not available (matching tools.json and ESP32-S3 driver required)")
    return pairs


def esp32(args, out, data):
    idf, gcc, s3, version = detect_tool_pairs(args)[0]
    chip = args.chip
    driver = s3.parent / ("xtensa-" + chip + "-elf-gcc")
    if not driver.is_file():
        raise RuntimeError(f"Official compiler driver not available for {chip}")
    toolchain = idf / ("tools/cmake/toolchain-" + chip + ".cmake")
    data.update({"idf_path": str(idf), "idf_version": (idf / "version.txt").read_text().strip(), "gcc": str(gcc), "gcc_version": version})
    print(f"ESP-IDF {data['idf_version']}; {version.splitlines()[0]}")
    env = dict(os.environ, IDF_PATH=str(idf), PATH=str(s3.parent) + os.pathsep + os.environ.get("PATH", ""))
    fingerprint = hashlib.sha256((str(idf) + str(driver) + version).encode() + toolchain.read_bytes()).hexdigest()[:12]
    build_dir = out / ("cmake-" + fingerprint)
    configured = command(["cmake", "-S", args.harness, "-B", build_dir, "-G", "Ninja",
                          "-DCMAKE_TOOLCHAIN_FILE=" + str(toolchain), "-DMIMOC_IDF_TARGET=" + chip,
                          "-DMIMOC_ABI_EXPECTED_C=" + str(args.abi_expected.resolve()),
                          "-DMIMOC_GENERATED_C=" + str(args.generated.resolve()), "-DMIMOC_ZIG_LIB=" + str(args.zig_lib.resolve())], out / "configure.log", env)
    if configured.returncode:
        data["stage_b"] = "FAIL"
        return configured.returncode
    probe = command(["cmake", "--build", build_dir, "--target", "abi_probe"], out / "abi-probe.log", env)
    if probe.returncode:
        data["stage_b"] = "FAIL"
        return probe.returncode
    commands_file = build_dir / "compile_commands.json"
    if commands_file.exists():
        data["compile_commands"] = json.loads(commands_file.read_text())
    flags_file = build_dir / "toolchain/cflags"
    if flags_file.exists():
        data["idf_cflags_response"] = flags_file.read_text()
    abi_object = next(path for path in build_dir.rglob("abi_probe.c.*") if path.suffix in [".o", ".obj"])
    abi_bin = out / "abi.bin"
    dump = command([s3.parent / "xtensa-esp-elf-objcopy", "--dump-section", ".rodata=" + str(abi_bin), abi_object], out / "abi-dump.log", env)
    if dump.returncode:
        data["stage_b"] = "FAIL"
        return dump.returncode
    count = 2 * len(ABI_NAMES)
    raw = abi_bin.read_bytes()
    if len(raw) != 4 * (count + 6):
        raise RuntimeError("Unexpected GCC ABI probe data length")
    values = struct.unpack("<" + str(count + 6) + "I", raw)
    actual = dict(zip(ABI_NAMES, [list(values[i:i+2]) for i in range(0, count, 2)]))
    expected = expected_abi(args.abi_expected)
    data.update({"chip": chip, "gcc_abi_size_alignment": actual, "zig_abi_size_alignment": expected,
                 "abi_mismatches": {name: {"zig": expected[name], "gcc": actual[name]} for name in ABI_NAMES if expected[name] != actual[name]}})
    mixed = expected_mixed_layout(args.abi_expected)
    data["mixed_layout"] = {"zig": mixed, "gcc": list(values[count:])}
    if mixed != list(values[count:]):
        data["abi_mismatches"]["mixed_struct"] = data["mixed_layout"]
    if data["abi_mismatches"]:
        print("ABI gate FAIL: " + json.dumps(data["abi_mismatches"]))
        data["stage_b"] = "FAIL"
        return 1
    print(f"ABI gate PASS: all {len(ABI_NAMES)} types match for {chip}")
    abi_check = command(["cmake", "--build", build_dir, "--target", "abi_expected"], out / "abi-expected.log", env)
    if abi_check.returncode:
        data["stage_b"] = "FAIL"
        return abi_check.returncode
    if args.abi_only:
        data["stage_b"] = "PASS"
        return 0
    result = command(["cmake", "--build", build_dir, "--clean-first", "--target", "mimoc_generated", "--verbose"], out / "xtensa-compile.log", env)
    data["stage_b"] = "PASS" if result.returncode == 0 else "FAIL"
    data["abi_assertions_failed"] = "static assertion failed" in result.stdout
    data["warning_count"] = len(re.findall(r"warning:", result.stdout))
    if result.returncode == 0:
        obj = next(path for path in (build_dir / "CMakeFiles/mimoc_generated.dir").rglob("*") if path.suffix in [".o", ".obj"])
        shutil.copyfile(obj, out / "mimoc_ui.o")
        data["object_bytes"] = obj.stat().st_size
        sizes = command([s3.parent / "xtensa-esp-elf-size", "-A", obj], out / "object-size.log", env)
        data["sections"] = {m.group(1): int(m.group(2)) for m in re.finditer(r"^([.\w]+)\s+(\d+)\s+\d+$", sizes.stdout, re.M)}
        objmeta = command([s3.parent / "xtensa-esp-elf-objdump", "-f", "-h", obj], out / "object-metadata.log", env)
        fmt = re.search(r"file format (\S+)", objmeta.stdout)
        data["object_format"] = fmt.group(1) if fmt else None
        if data["object_format"] != "elf32-xtensa-le" or "architecture: xtensa," not in objmeta.stdout:
            raise RuntimeError("Object is not the expected little-endian ELF32 Xtensa artifact")
        unresolved = command([s3.parent / "xtensa-esp-elf-nm", "-u", obj], out / "undefined-symbols.log", env)
        data["undefined_symbols"] = unresolved.stdout
        symbols = [line.split()[-1] for line in unresolved.stdout.splitlines() if line.strip()]
        # These are normal GCC 64-bit integer division helpers, not a Zig/LLVM
        # runtime. Verify the selected official toolchain actually provides them.
        builtins = sorted(set(symbols) & {"__divdi3", "__udivdi3"})
        data["compiler_builtins"] = builtins
        if builtins:
            library = command([driver, "-print-libgcc-file-name"], out / "libgcc-path.log", env)
            libgcc = Path(library.stdout.strip())
            if library.returncode or not libgcc.is_file():
                raise RuntimeError("Cannot locate the selected official GCC builtin runtime")
            definitions = command([s3.parent / "xtensa-esp-elf-nm", "-g", "--defined-only", libgcc], out / "libgcc-definitions.log", env)
            if definitions.returncode or any(not re.search(r"\b[TW]\s+" + re.escape(symbol) + r"$", definitions.stdout, re.M) for symbol in builtins):
                raise RuntimeError("Official libgcc does not define required compiler builtins")
            data["libgcc"] = str(libgcc)
        data["unexpected_undefined_symbols"] = [symbol for symbol in symbols if symbol not in {"memcpy", "memset", "memmove", "memcmp", "bzero", *builtins}]
        if any(call.returncode for call in [sizes, unresolved, objmeta]) or data["unexpected_undefined_symbols"]:
            data["stage_b"] = "FAIL"
            print("Object audit FAIL: " + repr(data["unexpected_undefined_symbols"]))
            return 1
    print(f"Stage B: {data['stage_b']}; metadata/logs: {out}")
    return result.returncode


def matrix(args, out, data):
    pairs = detect_tool_pairs(args)
    chosen = {}
    for pair in pairs:
        major = idf_version(pair[0])[0]
        if major in (5, 6):
            chosen.setdefault(major, pair)
    if set(chosen) != {5, 6}:
        raise RuntimeError("ABI matrix requires existing official ESP-IDF 5.x and 6.x pairs")
    original_idf, original_gcc = args.idf, args.gcc
    records = []
    failed = False
    for major, (idf, gcc, _, _) in sorted(chosen.items()):
        for chip in ["esp32", "esp32s2", "esp32s3"]:
            args.idf, args.gcc, args.chip, args.abi_only = str(idf), str(gcc), chip, True
            sub = out / f"idf{major}-{chip}"
            sub.mkdir(exist_ok=True)
            record = {}
            result = esp32(args, sub, record)
            (sub / "report.json").write_text(json.dumps(record, indent=2) + "\n")
            records.append(record)
            failed |= result != 0
    args.idf, args.gcc = original_idf, original_gcc
    data["matrix"] = records
    data["stage_b"] = "FAIL" if failed else "PASS"
    return int(failed)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=["host", "esp32", "abi-matrix"])
    for name in ["generated", "zig-lib", "outdir"]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--zig", required=True)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--driver", type=Path)
    parser.add_argument("--harness", type=Path)
    parser.add_argument("--cc")
    parser.add_argument("--idf")
    parser.add_argument("--gcc")
    parser.add_argument("--abi-expected", type=Path)
    parser.add_argument("--chip", choices=["esp32", "esp32s2", "esp32s3"], default="esp32s3")
    parser.add_argument("--abi-only", action="store_true")
    args = parser.parse_args()
    out = args.outdir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    data = {}
    try:
        data = metadata(args, out)
        result = host(args, out, data) if args.stage == "host" else (matrix(args, out, data) if args.stage == "abi-matrix" else esp32(args, out, data))
    except (RuntimeError, OSError, ValueError, StopIteration) as error:
        print(error, file=sys.stderr)
        data["error"] = str(error)
        data["stage_a" if args.stage == "host" else "stage_b"] = "BLOCKED" if "not available" in str(error) else "FAIL"
        result = 1
    (out / "report.json").write_text(json.dumps(data, indent=2) + "\n")
    return result


if __name__ == "__main__":
    sys.exit(main())
