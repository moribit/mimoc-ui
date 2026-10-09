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


def detect_tools(args):
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
                return idf.resolve(), gcc.resolve(), s3, version.stdout
    raise RuntimeError("Stage B blocked: official ESP-IDF Xtensa GCC not available (matching tools.json and ESP32-S3 driver required)")


def esp32(args, out, data):
    idf, gcc, s3, version = detect_tools(args)
    data.update({"idf_path": str(idf), "idf_version": (idf / "version.txt").read_text().strip(), "gcc": str(gcc), "gcc_version": version})
    print(f"ESP-IDF {data['idf_version']}; {version.splitlines()[0]}")
    env = dict(os.environ, IDF_PATH=str(idf), PATH=str(s3.parent) + os.pathsep + os.environ.get("PATH", ""))
    fingerprint = hashlib.sha256((str(idf) + str(s3) + version).encode() + (idf / "tools/cmake/toolchain-esp32s3.cmake").read_bytes()).hexdigest()[:12]
    build_dir = out / ("cmake-" + fingerprint)
    configured = command(["cmake", "-S", args.harness, "-B", build_dir, "-G", "Ninja",
                          "-DCMAKE_TOOLCHAIN_FILE=" + str(idf / "tools/cmake/toolchain-esp32s3.cmake"),
                          "-DMIMOC_GENERATED_C=" + str(args.generated.resolve()), "-DMIMOC_ZIG_LIB=" + str(args.zig_lib.resolve())], out / "configure.log", env)
    if configured.returncode:
        data["stage_b"] = "FAIL"
        return configured.returncode
    probe = command(["cmake", "--build", build_dir, "--target", "abi_probe"], out / "abi-probe.log", env)
    if probe.returncode:
        data["stage_b"] = "FAIL"
        return probe.returncode
    abi_object = next(path for path in build_dir.rglob("abi_probe.c.*") if path.suffix in [".o", ".obj"])
    abi_bin = out / "abi.bin"
    dump = command([s3.parent / "xtensa-esp-elf-objcopy", "--dump-section", ".rodata=" + str(abi_bin), abi_object], out / "abi-dump.log", env)
    if dump.returncode:
        return dump.returncode
    values = struct.unpack("<10I", abi_bin.read_bytes())
    data["gcc_abi_size_alignment"] = dict(zip(["pointer", "long_long", "double", "long_double", "uint64"], [list(values[i:i+2]) for i in range(0,10,2)]))
    print("GCC ABI: " + json.dumps(data["gcc_abi_size_alignment"]))
    result = command(["cmake", "--build", build_dir, "--target", "mimoc_generated", "--verbose"], out / "xtensa-compile.log", env)
    data["stage_b"] = "PASS" if result.returncode == 0 else "FAIL"
    data["abi_assertions_failed"] = "static assertion failed" in result.stdout
    data["warning_count"] = len(re.findall(r"warning:", result.stdout))
    commands_file = build_dir / "compile_commands.json"
    if commands_file.exists():
        data["compile_commands"] = json.loads(commands_file.read_text())
    flags_file = build_dir / "toolchain/cflags"
    if flags_file.exists():
        data["idf_cflags_response"] = flags_file.read_text()
    if result.returncode == 0:
        obj = next(path for path in (build_dir / "CMakeFiles/mimoc_generated.dir").rglob("*") if path.suffix in [".o", ".obj"])
        shutil.copyfile(obj, out / "mimoc_ui.o")
        data["object_bytes"] = obj.stat().st_size
        command([s3.parent / "xtensa-esp-elf-size", obj], out / "object-size.log", env)
        unresolved = command([s3.parent / "xtensa-esp-elf-nm", "-u", obj], out / "undefined-symbols.log", env)
        data["undefined_symbols"] = unresolved.stdout
    print(f"Stage B: {data['stage_b']}; metadata/logs: {out}")
    return result.returncode


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=["host", "esp32"])
    for name in ["generated", "zig-lib", "outdir"]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--zig", required=True)
    parser.add_argument("--native", type=Path)
    parser.add_argument("--driver", type=Path)
    parser.add_argument("--harness", type=Path)
    parser.add_argument("--cc")
    parser.add_argument("--idf")
    parser.add_argument("--gcc")
    args = parser.parse_args()
    out = args.outdir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    data = {}
    try:
        data = metadata(args, out)
        result = host(args, out, data) if args.stage == "host" else esp32(args, out, data)
    except (RuntimeError, OSError, ValueError, StopIteration) as error:
        print(error, file=sys.stderr)
        data["error"] = str(error)
        data.setdefault("stage_a" if args.stage == "host" else "stage_b", "BLOCKED" if "not available" in str(error) else "FAIL")
        result = 1
    (out / "report.json").write_text(json.dumps(data, indent=2) + "\n")
    return result


if __name__ == "__main__":
    sys.exit(main())
