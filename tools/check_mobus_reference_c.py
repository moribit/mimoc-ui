#!/usr/bin/env python3
"""Compile generated reference C and compare every scenario to native Zig."""
import argparse
from pathlib import Path
import subprocess
import tempfile

p=argparse.ArgumentParser(description=__doc__)
p.add_argument("--generated",type=Path,required=True)
p.add_argument("--zig-lib",type=Path,required=True)
p.add_argument("--snapshot",required=True)
p.add_argument("--driver",type=Path,required=True)
p.add_argument("--outdir",type=Path,required=True)
a=p.parse_args()
a.outdir.mkdir(parents=True,exist_ok=True)
def run():
    exe=a.outdir/"reference-c"
    obj=a.outdir/"reference.o"
    # Standalone library policy; disable host-only stack runtime instrumentation.
    # This does not change ABI, generated C, zig.h, or any ABI assertion.
    compile=subprocess.run(["clang","-std=c11","-O2","-ffreestanding","-fno-stack-protector","-Wall","-Wextra","-I"+str(a.zig_lib),"-c",str(a.generated),"-o",str(obj)],capture_output=True,text=True)
    (a.outdir/"compiler.log").write_text(compile.stdout+compile.stderr)
    if compile.returncode:
        print(compile.stderr)
        raise SystemExit(compile.returncode)
    print("host generated-C compiler warnings:",compile.stderr.count("warning:"),"(full compiler.log retained)")
    undefined=subprocess.check_output(["nm","-u",str(obj)],text=True)
    (a.outdir/"undefined.txt").write_text(undefined)
    symbols={line.split()[-1].lstrip("_") for line in undefined.splitlines() if line.strip()}
    forbidden=[s for s in symbols if s not in {"memcpy","memset","memmove","bzero"}]
    if forbidden:raise SystemExit("FAIL: reference object has unexpected runtime/platform symbols: "+", ".join(forbidden))
    subprocess.run(["clang",str(obj),str(a.driver),"-o",str(exe)],check=True)
    names=subprocess.check_output([a.snapshot,"--list"],text=True).splitlines()
    generated=subprocess.check_output([str(exe),str(len(names))])
    native=b"".join(subprocess.check_output([a.snapshot,name,"--raw"]) for name in names)
    if len(generated)!=len(native):raise SystemExit("FAIL: frame count or byte length differs")
    for i,(c,z) in enumerate(zip(generated,native)):
        if c!=z:raise SystemExit(f"FAIL: {names[i//1024]}, first differing byte {i%1024}")
    print(f"PASS: reference native Zig == generated C: {len(names)} frames x 1024 bytes; no platform/heap dependency")
run()
