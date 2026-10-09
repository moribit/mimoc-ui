#!/usr/bin/env python3
"""Compare logical page-LSB OLED bytes, report exact pixels and write P4 panels."""
import argparse
from pathlib import Path
import subprocess


def pbm(data):
    out = bytearray(1024)
    for y in range(64):
        for x in range(128):
            if data[(y // 8) * 128 + x] & (1 << (y % 8)):
                out[y * 16 + x // 8] |= 128 >> (x % 8)
    return b"P4\n128 64\n" + out


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--snapshot", required=True)
    p.add_argument("--screen", required=True)
    p.add_argument("--expected", type=Path, required=True)
    p.add_argument("--outdir", type=Path, default=Path("zig-out/mobus-diff"))
    a = p.parse_args()
    expected = a.expected.read_bytes()
    actual = subprocess.check_output([a.snapshot, a.screen, "--raw"])
    if len(expected) != 1024 or len(actual) != 1024:
        p.error("expected and actual must each contain exactly 1024 page-LSB bytes")
    xor = bytes(x ^ y for x, y in zip(expected, actual))
    pixels = sum(x.bit_count() for x in xor)
    byte_count = sum(x != 0 for x in xor)
    first = next((i for i, x in enumerate(xor) if x), None)
    point = None if first is None else (first % 128, (first // 128) * 8 + next(b for b in range(8) if xor[first] & (1 << b)))
    print(f"screen: {a.screen}\nmatching pixels: {8192 - pixels}\ndifferent pixels: {pixels}\nfirst differing x/y: {point}\nfirst differing framebuffer byte: {first}\ntotal mismatched bytes: {byte_count}")
    a.outdir.mkdir(parents=True, exist_ok=True)
    for name, data in [("expected", expected), ("actual", actual), ("xor", xor)]:
        (a.outdir / (name + ".pbm")).write_bytes(pbm(data))
        (a.outdir / (name + ".raw")).write_bytes(data)
    print("PASS" if pixels == 0 else "FAIL")
    return pixels != 0


if __name__ == "__main__":
    raise SystemExit(main())
