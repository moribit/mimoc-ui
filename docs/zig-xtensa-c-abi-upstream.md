# Draft upstream issue / PR: correct Xtensa C scalar alignment

This is a draft only; no issue or PR was submitted. Evidence and complete ABI measurements are in [xtensa-c-abi-patch.md](xtensa-c-abi-patch.md).

## Suggested title

Target: correct Xtensa/XtensaEB C primitive maximum alignment to 8

## Problem

Official upstream Zig 0.17.0 (`afee4225358129f909e01dfaed265dca0977befe`) lowers this freestanding module to C, but official Espressif GCC rejects its ABI assertions:

```zig
pub export fn mimoc_abi_minimal(value: u32) u32 {
    return value +% 1;
}
```

```sh
zig build-obj minimal.zig -O small -ofmt=c \
  -target xtensa-freestanding -mcpu generic -femit-bin=minimal.c
xtensa-esp32s3-elf-gcc -std=c11 -Os -mlongcalls \
  -I /official/zig-0.17.0/lib -c minimal.c -o minimal.o
```

The generated file expects size/alignment 8/4 for signed/unsigned long long, double (`zig_f64`) and long double. Espressif GCC reports 8/8. A module with no imports and only a u32 argument/result therefore fails before compiling any application logic.

## Evidence

- Official IDF 5.5.3 GCC 14.2.0 (`esp-14.2.0_20251107`) and IDF 6.0.1 GCC 15.2.0 (`esp-15.2.0_20251204`).
- Actual object-based sizeof/_Alignof measurements for 27 scalar/pointer/standard typedef types on ESP32, ESP32-S2 and ESP32-S3: all six pairs agree. Only the four primitive alignments differ from stock Zig.
- Pointer/size_t/ptrdiff_t/intptr_t/uintptr_t: 4/4. Long-long, double, long-double, int64_t and uint64_t: 8/8. Smaller scalar types have natural 1/2/4 alignment.
- Mixed extern aggregate offsets are also incorrect before the patch: `{u8, c_ulonglong, f64, u8}` has Zig size/alignment 24/4, offsets 0/4/12/20; GCC has 32/8, offsets 0/8/16/24.
- The generic [GCC Xtensa target](https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-15/gcc/config/xtensa/xtensa.h) and [storage-layout implementation](https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-15/gcc/stor-layout.cc) support natural 64-bit scalar alignment independently of the endianness configuration. Big-endian and non-Espressif compiler executions were not available and remain a review point.

## Root cause

`lib/std/Target.zig:cTypeAlignment` rounds C scalar size up to a power of two and caps it by architecture. Xtensa/XtensaEB currently have cap 4. `src/Type.zig:abiAlignment` uses that helper for C long-long/long-double and matching-width double. The C emitter uses the compiler's actual Type ABI values in its static assertions. This is a type/layout error, not an assertion that should be disabled.

Fixed-width i64/u64 use the integer alignment helper and already allow 8 on Xtensa, which explains the inconsistent uint64_t assertion. Sizes, fixed-width integer helpers, `zig.h`, and C code generation itself require no change.

## Proposed change

Move `.xtensa` and `.xtensaeb` from the 4-byte to the 8-byte maximum-alignment group in `cTypeAlignment`. Patch: [zig-0.17.0-xtensa-c-abi.patch](../tools/patches/zig-0.17.0-xtensa-c-abi.patch), one file, +2/-2 lines. Other architecture switch arms are unchanged.

This is proposed as an Xtensa GCC ABI correction, not an ESP32-S3 CPU model or an application workaround. Confirm any alternative configured/vendor Xtensa ABI during review; the execution-free binary measurements specifically cover the official Espressif ESP32 family.

## Regression tests to accompany upstream integration

1. A Target unit test should instantiate freestanding generic Xtensa and XtensaEB and verify each `Target.CType` size/alignment: char 1/1; short/ushort 2/2; int/uint/long/ulong/float 4/4; longlong/ulonglong/double/longdouble 8/8. Verify pointer width and cMaxIntAlignment remain 32 bits / 8 bytes.
2. Compiler-semantic tests should compile actual `@alignOf(c_longlong)`, `@alignOf(c_ulonglong)`, `@alignOf(f64)` and `@alignOf(c_longdouble)` constants for Xtensa and verify 8. Testing only an imported patched std.Target helper is insufficient because the compiler embeds its own helper copy.
3. Add the mixed extern struct and verify size/alignment 32/8 and field offsets 0/8/16/24. Emit to C and compile unchanged output with the vendor compiler, preserving scalar and aggregate assertions.
4. Keep representative non-Xtensa target ABI tests; the patch changes only two architecture enum cases. Native/RV32/macOS project builds passed with the unmodified official invoking compiler; this is not a claim that a LLVM-disabled rebuilt compiler replaces those production build tools.

The local repository already provides actual-semantic/object gates in `integration/esp32s3-c-backend/abi_expect.zig`, `abi_probe.c` and `tools/check_c_backend.py`, including all 27 types and aggregate offsets. They fail with the stock compiler and pass with the rebuilt corrected compiler on all six SDK/chip pairs.

## Before / after validation

- Stock 0.17.0: host C lowering and 2060 × 1024-byte native-vs-C framebuffer equality PASS; target-generated Xtensa C FAIL on four scalar assertions.
- Corrected 0.17.0 source rebuild: minimal and complete fixed-capacity UI probes compile to official S3 GCC objects under both SDK versions; assertions and generated C are untouched; no C emitter/backend patch.
- Host equivalence remains 2060 frames × 1024 bytes PASS. Object audit finds only normal C memory functions and GCC 64-bit division helpers, confirmed in the selected official libgcc archive.

Editing only a binary distribution's std library does not repair compiler-semantic layouts. Rebuild with the patched library selected as the first build argument (`zig build --zig-lib=/source/lib ...`). No native Xtensa or LLVM Xtensa backend is involved.

Firmware linking, on-device execution, calling-convention integration and big-endian vendor execution were outside this experiment. Those limits should remain explicit in any upstream submission.
