# Xtensa C ABI metadata patch experiment

Date: 2026-10-09. This follows the stock-compiler experiment in [c-backend-portability.md](c-backend-portability.md). Its stock Stage B failure remains valid; this is a separate, explicitly modified upstream-source compiler experiment.

## Baseline and scope

- Official upstream tag **0.17.0**, commit **afee4225358129f909e01dfaed265dca0977befe**, verified against the [official repository tag](https://codeberg.org/ziglang/zig/src/tag/0.17.0).
- [Official source archive](https://ziglang.org/download/0.17.0/zig-0.17.0.tar.xz), SHA256 `b6c7f1728f043700d6529bac980800792f824256a9d2f1839b3d62beed0b8abd`, checked against the [official release index](https://ziglang.org/download/index.json).
- The distribution and source archive have byte-identical original `lib/std/Target.zig`, SHA256 `070da5555e713ad68856ff89d276174b78c2bd77d343f45eafbc1e4d34abf0e0`.
- Patch: `tools/patches/zig-0.17.0-xtensa-c-abi.patch`: **1 file, 2 added lines / 2 removed lines**. Moves `.xtensa` and `.xtensaeb` from the 4-byte to the 8-byte maximum in `cTypeAlignment`.
- No native Xtensa codegen, LLVM Xtensa backend, fork source, generated-C editing, assertion suppression, `zig.h` change, Core change or GCC ABI flag override.

## Full ABI measurement

Every cell is `sizeof / _Alignof` in bytes. GCC values were measured from object `.rodata`, without executing Xtensa instructions. IDF toolchain CMake files and, for IDF 6, its official SoC project include supply chip/compiler flags. IDF 5.5.3 uses Espressif GCC 14.2.0 `esp-14.2.0_20251107`; IDF 6.0.1 uses GCC 15.2.0 `esp-15.2.0_20251204`.

The **27 types have identical measured ABI on ESP32, ESP32-S2 and ESP32-S3 with both SDK/compiler pairs**. The table is the ESP32-S3 result; the other five records agree in every cell. Zig expectations come from actual target compiler semantics (`@sizeOf` / `@alignOf`), not a duplicated numeric ABI table.

| C type | Stock Zig 0.17.0 | IDF 5.5.3 GCC 14.2 | IDF 6.0.1 GCC 15.2 | Patched Zig |
| --- | --- | --- | --- | --- |
| char | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| signed_char | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| unsigned_char | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| short | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| unsigned_short | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| int | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| unsigned_int | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| long | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| unsigned_long | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| long_long | 8 / 4 | 8 / 8 | 8 / 8 | 8 / 8 |
| unsigned_long_long | 8 / 4 | 8 / 8 | 8 / 8 | 8 / 8 |
| float | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| double | 8 / 4 | 8 / 8 | 8 / 8 | 8 / 8 |
| long_double | 8 / 4 | 8 / 8 | 8 / 8 | 8 / 8 |
| pointer | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| size_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| ptrdiff_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| intptr_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| uintptr_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| int8_t | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| uint8_t | 1 / 1 | 1 / 1 | 1 / 1 | 1 / 1 |
| int16_t | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| uint16_t | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 |
| int32_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| uint32_t | 4 / 4 | 4 / 4 | 4 / 4 | 4 / 4 |
| int64_t | 8 / 8 | 8 / 8 | 8 / 8 | 8 / 8 |
| uint64_t | 8 / 8 | 8 / 8 | 8 / 8 | 8 / 8 |

The mixed aggregate `struct { uint8_t prefix; unsigned long long integer; double number; uint8_t suffix; }` adds an independent layout regression:

| Measurement | Stock Zig | Official GCC / corrected expectation |
| --- | --- | --- |
| size / alignment | 24 / 4 | 32 / 8 |
| field offsets | 0, 4, 12, 20 | 0, 8, 16, 24 |

No additional primitive ABI mismatch was found. Plain char signedness is not part of this size/alignment probe. Pointer-based Zig types represent the measured C size_t/ptrdiff_t/intptr_t/uintptr_t layouts; the probe does not claim identical typedef spelling.

## Cause and propagation into generated C

The official 0.17.0 source path is:

1. `lib/std/Target.zig:CType` is a plain enum of C scalar kinds. This release has no `Target.CType.Align` or `cTypePreferredAlignment` API.
2. `cTypeBitSize` supplies scalar widths; `cTypeByteSize` turns them into storage sizes. For freestanding Xtensa, long-long/double/long-double are 64 bits. None of these size helpers needs a patch.
3. `cTypeAlignment` rounds scalar byte size to a power of two, then applies an architecture maximum. Stock Xtensa/XtensaEB incorrectly use maximum 4.
4. `src/Type.zig:abiAlignment` routes c_longlong/c_ulonglong/c_longdouble through `cTypeAlign`; f64 also uses the double C alignment when its width matches. `cTypeAlign` calls `target.cTypeAlignment`. `@alignOf` and aggregate layout share that compiler path.
5. `src/codegen/c/type/render_defs.zig:writeStaticAssertTypeLayout` passes `Type.abiSize` and `Type.abiAlignment` into `writeStaticAssertCTypeLayout`, which emits the unchanged `zig_static_assert(sizeof(...) == ... && zig_alignOf(...) == ..., "abi mismatch")`.
6. Fixed-width i64/u64 use `std.zig.target.intAlignment`, with Xtensa `cMaxIntAlignment` already allowing 8. This explains the previous uint64_t-versus-c_ulonglong discrepancy. The fixed-width helpers and C emitter do not need modification.

There is no separate preferred-alignment correction to make in these C scalar paths. The metadata error affects genuine aggregate offsets, not merely an overstrict assertion.

## Is it an ESP32-S3 workaround?

The six official compiler measurements show that this is not S3-only. The [upstream GCC 15 Xtensa target definition](https://raw.githubusercontent.com/gcc-mirror/gcc/releases/gcc-15/gcc/config/xtensa/xtensa.h) supplies 64-bit long-long, 32-bit pointers and a 128-bit BIGGEST_ALIGNMENT; it has no 32-bit cap on scalar double/long-long alignment. GCC storage layout derives natural alignment from mode size subject to the target maximum. Its byte/word-endianness switches do not change that scalar alignment rule.

This supports an **Xtensa GCC ABI correction in the target layer**, including the existing big-endian counterpart, rather than a CPU-model or UI-specific branch. ESP8266 and non-Espressif/big-endian vendor compilers were not executable-tested. An upstream reviewer should confirm any alternative Xtensa ABI before merging; the measured operational claim here is limited to official Espressif ESP32-family compilers. No fictional ESP32-S3 Zig CPU model was added: C lowering uses `xtensa-freestanding -mcpu generic`, and the official SDK-selected GCC driver handles S3 instructions.

## Distribution-library experiment and compiler rebuild

Changing only `lib/std/Target.zig` in an isolated copy of the official binary distribution **does not change generated scalar assertions**: they still request alignment 4. The compiler embeds this Target helper when the compiler executable is built.

The compiler must be rebuilt from the official source with the same four-line patch. Importantly, building compiler source with the bootstrap distribution default library also embeds the old table. The build must select the patched library using **`zig build --zig-lib=/absolute/source/lib ...`**, as the first build argument. A rebuild that omits this is rejected by the new ABI gate even though the displayed version remains 0.17.0.

The experiment builds a host compiler with `-Denable-llvm=false`; no LLVM/Clang/LLD libraries are needed in the resulting compiler. The existing official binary uses its existing host LLVM backend via `-Duse-llvm=true` to build that compiler. This does not add an Xtensa LLVM backend. All normal native UI tests/RV32/macOS builds continue using the unmodified invoking official Zig. Only C lowering selects the isolated executable.

Equivalent compiler build:

```sh
zig build --zig-lib=/absolute/zig-0.17.0/lib \
  -Denable-llvm=false -Duse-llvm=true -Dversion-string=0.17.0 \
  -Doptimize=fast -Dno-lib -Dno-langref \
  --prefix /temporary/compiler-build --cache-dir /temporary/compiler-cache
```

Copy the resulting `bin/zig` into the isolated distribution, alongside the matching patched library. No compiler binary is committed or distributed by this repository.

## Reproduce using the deterministic preparation tool

Download only the official source archive linked above, or use an existing verified copy. The helper itself never downloads tools, modifies the installed compiler, or updates Core.

```sh
python3 tools/prepare_zig_xtensa_abi.py \
  --zig /absolute/official-0.17.0/zig \
  --source-archive /temporary/zig-0.17.0.tar.xz \
  --outdir /temporary/new-isolated-workspace

zig build check-c-backend-host \
  -Dzig-c-backend=/temporary/new-isolated-workspace/distribution/zig
zig build check-esp32s3-c-abi \
  -Dzig-c-backend=/temporary/new-isolated-workspace/distribution/zig
zig build check-esp32s3-c-target \
  -Dzig-c-backend=/temporary/new-isolated-workspace/distribution/zig
zig build check-xtensa-c-abi-matrix \
  -Dzig-c-backend=/temporary/new-isolated-workspace/distribution/zig
zig build check-portability \
  -Dzig-c-backend=/temporary/new-isolated-workspace/distribution/zig
```

The preparation tool pins the official source checksum and original Target.zig checksum, applies the committed patch with no fuzz, verifies the resulting edit is exactly the approved two-architecture movement, records bootstrap/output binary and patch hashes, and verifies `zig.h` is unchanged. It refuses existing output directories and nonmatching baselines. `--library-only` reproduces the insufficient library-only approach. Build logs and `provenance.json` stay in disposable output.

`check-portability` now uses **target-specific C**, not the host artifact, and runs full UI compilation only after host equivalence and minimal ABI compilation pass. The historical `check-esp32s3-c` same-host-artifact target remains an explicit negative diagnostic: its 64-bit host layout cannot be reused on Xtensa32 even with this patch. The default aggregate with stock Zig still fails; there is no implicit compiler substitution or silent skip.

`abi_expect.zig` emits the 27 compiler-semantic pairs and mixed-struct layout. The gate compares them with `abi_probe.c` object data, then compiles the untouched expectation C (including its scalar/aggregate assertions) and the minimal/full probe C. Object audit records sections/undefined symbols and rejects unexpected dependencies and non-Xtensa object formats. Compiler/library/header hashes are included in each probe report. Mismatches remain nonzero failures. Matrix checks require both existing SDK major versions and all three official drivers.

## Results and operational recommendation

**Stage B.5: CONDITIONAL PASS. Final recommendation: CONDITIONAL GO for the object-compilation route.** The tiny target-layer patch is sufficient; a compiler binary rebuild is required. Production firmware/library integration is still unverified.

| Check | Before: stock 0.17.0 | After: isolated rebuilt 0.17.0 + patch |
| --- | --- | --- |
| Stage A native vs host C | PASS | PASS: 2060 frames × 1024 bytes; 1717 visible changes |
| Minimal Xtensa C → S3 object | FAIL: four assertions | PASS on official GCC 14.2 and 15.2 |
| Full mimoc-ui Xtensa C → S3 object | FAIL: four assertions | PASS on official GCC 14.2 and 15.2 |
| 27-type + mixed-aggregate ABI matrix | Four scalar mismatches and aggregate mismatch | PASS on all six SDK/chip pairs |
| check-portability | FAIL | PASS with explicit `-Dzig-c-backend` |
| Existing tests / ReleaseSmall / RV32 / macOS simulator and Studio compile | PASS | PASS with ordinary unmodified invoking compiler |

Minimal output: **3624 bytes / 52 lines**, object **944 bytes**, `.text` **7 bytes**, `.rodata` **0**, `.data` **0**, `.bss` **0**, no undefined symbols (GCC 15.2). Its generated assertions remain enabled and now explicitly check alignment 8. Full target-specific UI C: **329684 bytes / 9388 lines**.

| Full UI object measurement (bytes) | IDF 5.5.3 / GCC 14.2 | IDF 6.0.1 / GCC 15.2 |
| --- | ---: | ---: |
| Object file | 48148 | 45176 |
| .text | 10638 | 10394 |
| .literal | 576 | 472 |
| .rodata | 2729 | 2633 |
| .data | 1768 | 1768 |
| .bss | 4 | 4 |

`objdump` identifies **elf32-xtensa-le**, relocatable Xtensa objects. File size includes symbol tables, relocation entries and Xtensa metadata; the section figures are object measurements, not final firmware Flash/RAM estimates. Both UI objects have exactly these undefined symbols:

```text
__divdi3
__udivdi3
memcpy
memset
```

The division helpers are **GCC compiler builtins**, both found as defined symbols in each selected S3 toolchain `libgcc.a` via official `nm`. They are reported by the audit and are not silently mistaken for a Zig runtime. A future firmware link must supply normal C memory primitives and GCC runtime support; it was deliberately not attempted. No malloc/free, pthread, host-only, Zig-specific or LLVM-specific runtime symbol appeared.

GCC reports **28 warnings** for full generated C: ten in untouched zig.h (unused helper artifacts and two unused static Windows declarations) and eighteen in generated C (thirteen unused assigned temporaries, three unused constants, two redundant u16 range comparisons in saturating animation arithmetic). The Windows declarations do not create object dependencies. The range warnings point to comparisons with UINT16_MAX after a u16 operation, not an ABI error; all host framebuffer semantics checks pass. Warnings are recorded without suppression. Future target execution is still needed to establish Xtensa runtime semantics.

Host generated C remains **330828 bytes / 9390 lines**, with the previous 24 Clang warnings and 86152-byte comparison executable. Generated internal symbol IDs can differ between compiler builds; byte equality is required for framebuffer output, not generated-source spelling.

The corrected compiler was built locally from the checksum-verified official archive with the explicit patched `--zig-lib` command above. Library-only preparation was also exercised through the helper. The full helper source-build command mirrors the successful manual rebuild; a second cold end-to-end helper rebuild was not performed. The local source rebuild took several minutes, producing a roughly 23 MiB host executable; peak RSS was not measured (the upstream build step specifies an 8 GB maximum-RSS budget).

For traceability, this local rebuilt executable SHA256 is `874c9bfd19f5f220ebc1b73b3ad46953a9c0f03f3db365e2841fb7f7048e8376`, corrected Target.zig SHA256 `4b99d8a2aa02085df0eccfbd083932d0cae1c699889118e6b9e20d7439150b73`, patch SHA256 `5dc048f0be56f78a2cfc3266efbd7af23dc085f6526fa32ce9315623736b882e`. The executable hash is build-environment-specific, not a promise of bit-identical compiler builds across hosts. Local executable: `/tmp/mimoc-zig-abi-library/zig`.

Logs/reports and `.o` artifacts are printed by each step under the build cache. In this session the final default-SDK UI report is `/tmp/mimoc-cache/o/b4ccd2160db3e900d1c44dfba64d659d/esp32s3-target/report.json`; its sibling `mimoc_ui.o` is the audited object. The IDF 5 counterpart is `/tmp/mimoc-cache/o/3394f44813512c7f9ae6a62d45aa35d8/esp32s3-target/report.json`.

The preferred operation is **upstream acceptance and an official release containing the correction**. Until then, deterministic local patch plus isolated source rebuild is an explicit additional build dependency. It is not an unmodified official binary workflow, although its only compiler sources/toolchains are official upstream Zig and Espressif GCC. Pin the release/tag/archive, track the tiny patch, retain ABI/semantics/vendor gates on upgrades, and stop if patch or ABI validation fails.

A compiler rebuild increases cold-build time and memory/CI cost. Keep it out of ordinary test/build paths, cache a provenance-keyed local compiler artifact where appropriate, and do not distribute a custom compiler as a permanent library dependency. Existing CI continues to use stock 0.17.0 for native/RV32/host semantics and does not install a huge SDK or build this compiler. No patched-compiler GitHub runner execution was performed.

[zig-xtensa-c-abi-upstream.md](zig-xtensa-c-abi-upstream.md) contains an issue/PR draft and regression-test rationale; nothing was posted upstream. No firmware link, hardware execution, FreeRTOS, production C ABI or application integration was attempted. Compiler-object success cannot establish on-device rendering correctness or complete final-link runtime support.
