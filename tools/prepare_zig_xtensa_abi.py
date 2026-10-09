#!/usr/bin/env python3
"""Create an isolated, explicitly patched upstream compiler. Never edits installed Zig.

The caller supplies the official release archive; this tool does not download tools.
Only lib/std/Target.zig may change. Output is disposable, not a vendored compiler.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import time

SOURCE_SHA256 = "b6c7f1728f043700d6529bac980800792f824256a9d2f1839b3d62beed0b8abd"
OFFICIAL_TAG_COMMIT = "afee4225358129f909e01dfaed265dca0977befe"
TARGET_BEFORE = "070da5555e713ad68856ff89d276174b78c2bd77d343f45eafbc1e4d34abf0e0"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(argv, log=None, cwd=None):
    print("$ " + " ".join(str(v) for v in argv), flush=True)
    if log:
        with log.open("w") as stream:
            subprocess.run([str(v) for v in argv], cwd=cwd, stdout=stream,
                           stderr=subprocess.STDOUT, check=True)
    else:
        subprocess.run([str(v) for v in argv], cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-archive", type=Path, required=True)
    parser.add_argument("--zig", type=Path, required=True, help="Existing official 0.17.0 distribution executable")
    parser.add_argument("--outdir", type=Path, required=True, help="New disposable directory (must not exist)")
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--library-only", action="store_true", help="Diagnostic: patch copied library without rebuilding")
    args = parser.parse_args()
    zig = args.zig.resolve()
    patch = Path(__file__).resolve().parent / "patches/zig-0.17.0-xtensa-c-abi.patch"
    if args.jobs < 1:
        raise ValueError("jobs must be positive")
    if subprocess.check_output([str(zig), "version"], text=True).strip() != "0.17.0":
        raise RuntimeError("Requires the official exact 0.17.0 baseline")
    if sha(args.source_archive) != SOURCE_SHA256:
        raise RuntimeError("Official 0.17.0 source archive checksum mismatch")
    if sha(zig.parent / "lib/std/Target.zig") != TARGET_BEFORE:
        raise RuntimeError("Installed distribution Target.zig differs from pinned upstream baseline")
    out = args.outdir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    distro = out / "distribution"
    shutil.copytree(zig.parent, distro)
    with tarfile.open(args.source_archive) as archive:
        # The checksum fixes the official archive; data filter also rejects unsafe paths.
        archive.extractall(out, filter="data")
    source = out / "zig-0.17.0"
    target = source / "lib/std/Target.zig"
    if sha(target) != TARGET_BEFORE:
        raise RuntimeError("Source archive Target.zig does not match baseline")
    run(["patch", "--batch", "--fuzz=0", "-p1", "-i", patch], out / "patch.log", source)
    changed = target.read_bytes()
    # Ensure the committed patch is exactly the two-architecture table movement.
    baseline = (zig.parent / "lib/std/Target.zig").read_text()
    expected = baseline.replace("            .xtensa,\n            .xtensaeb,\n            => 4,", "            => 4,")
    expected = expected.replace("            .thumbeb,\n            => 8,", "            .thumbeb,\n            .xtensa,\n            .xtensaeb,\n            => 8,")
    if changed != expected.encode() or expected == baseline:
        raise RuntimeError("Patch changed more than the approved target ABI table")
    (distro / "lib/std/Target.zig").write_bytes(changed)
    record = {"tag": "0.17.0", "official_tag_commit": OFFICIAL_TAG_COMMIT,
              "source_archive_sha256": SOURCE_SHA256, "bootstrap_zig": str(zig),
              "bootstrap_binary_sha256": sha(zig), "patch_sha256": sha(patch),
              "target_before_sha256": TARGET_BEFORE, "target_after_sha256": sha(target),
              "library_only": args.library_only}
    (out / "provenance.json").write_text(json.dumps(record, indent=2) + "\n")
    if not args.library_only:
        start = time.monotonic()
        argv = [zig, "build", "--zig-lib=" + str(source / "lib"), "-Denable-llvm=false", "-Duse-llvm=true", "-Dversion-string=0.17.0",
                "-Doptimize=fast", "-Dno-lib", "-Dno-langref", "-j" + str(args.jobs),
                "--prefix", out / "compiler-build", "--cache-dir", out / "cache"]
        print(f"Rebuilding official compiler; log: {out / 'compiler-build.log'}", flush=True)
        run(argv, out / "compiler-build.log", source)
        shutil.copy2(out / "compiler-build/bin/zig", distro / "zig")
        record["compiler_build_seconds"] = round(time.monotonic() - start, 1)
        record["compiler_build_command"] = [str(v) for v in argv]
        minimal = Path(__file__).resolve().parent.parent / "integration/esp32s3-c-backend/minimal.zig"
        emitted = out / "minimal.c"
        run([distro / "zig", "build-obj", minimal, "-target", "xtensa-freestanding", "-mcpu", "generic",
             "-O", "small", "-ofmt=c", "-femit-bin=" + str(emitted)], out / "minimal-generation.log", out)
        text = emitted.read_text()
        for c_type in ["signed long long", "unsigned long long", "long double", "zig_f64"]:
            assertion = f'sizeof({c_type}) == 8 && zig_alignOf({c_type}) == 8, "abi mismatch"'
            if assertion not in text:
                raise RuntimeError(f"Rebuilt compiler did not apply the ABI correction: {c_type}")
        record["corrected_assertions_verified"] = True
    record["output_binary_sha256"] = sha(distro / "zig")
    record["zig_h_unchanged"] = sha(distro / "lib/zig.h") == sha(zig.parent / "lib/zig.h")
    if not record["zig_h_unchanged"]:
        raise RuntimeError("zig.h unexpectedly changed")
    (out / "provenance.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Isolated Zig: {distro / 'zig'}")
    if args.library_only:
        print("Library-only diagnostic: compiler-semantic ABI values still need validation.")


if __name__ == "__main__":
    main()
