# C backend portability: upstream Zig 0.17 → ESP32-S3

Date: 2026-10-09. Source baseline: main `86012b4`.

This report records the **unmodified official binary** experiment. The subsequent isolated upstream-source ABI patch/rebuild experiment is documented in [xtensa-c-abi-patch.md](xtensa-c-abi-patch.md). Current build gates compare all 27 primitive/typedef layouts plus a mixed aggregate, and `check-portability` now selects target-specific generation; the original stock failures below remain historical evidence.

**Stage A: PASS. Stage B: FAIL (upstream target ABI incompatibility). Recommendation: NO-GO for production with the unmodified, fixed upstream Zig 0.17.0 tested here.** The shared Zig UI implementation survives C lowering and host execution, but neither the literal host C artifact nor the correctly pointer-sized Xtensa regeneration can currently produce the requested ESP32-S3 UI object with official GCC. A future upstream ABI fix would justify reevaluating this route; this report does not claim that such a fix alone proves production suitability.

No Xtensa Zig fork, replacement backend, downloaded toolchain, handwritten renderer, disabled ABI assertion or Core workaround was used. Generated C stays in build output and is not committed. There was no ESP32-S3 firmware link, runtime, flashing, Mobus_ESP_IDF change, LovyanGFX, FreeRTOS integration or Japanese-font port.

## Reproduce

```sh
zig version                           # must be exactly 0.17.0
zig build emit-c                      # zig-out/c-backend/mimoc_ui.c and matching zig.h
zig build check-c-backend-host         # compile/link/run and byte equality
zig build c-backend-host               # same check + install logs/compare binary under c-backend/host
zig build test
zig build test -Doptimize=small
zig build check-embedded
zig build                             # existing macOS simulator / Studio / Desktop compile

zig build check-esp32s3-c              # strict Stage B: SAME host-generated C; currently FAIL
zig build emit-c-xtensa
zig build check-esp32s3-c-target        # diagnostic: per-target generation; currently FAIL
zig build emit-c-abi-minimal
zig build check-esp32s3-c-abi           # one-function reproducer without Core; currently FAIL
zig build check-portability            # includes strict Stage B; intentionally cannot PASS today
```

`check-c-backend` aliases `check-c-backend-host`; `c-backend` aliases `emit-c`. Stage B steps depend on a successful host equivalence run. Missing official tools produce `Stage B blocked: official ESP-IDF Xtensa GCC not available` and a nonzero status. They never install anything or silently skip a missing toolchain. These probes are opt-in; normal `test`, `check-embedded`, `run`, `studio` and installation are independent of Python/Clang/ESP-IDF probe dependencies.

The tests use Python 3's standard library. Stage B additionally requires existing CMake/Ninja. Select an existing official pair explicitly if needed:

```sh
zig build check-esp32s3-c-target \
  -Desp-idf=/path/to/esp-idf \
  -Dxtensa-gcc=/path/to/xtensa-esp-elf-gcc
```

The detector considers IDF-managed tools first, then PATH and already-installed PlatformIO packages. It verifies Espressif's compiler version against the selected IDF `tools/tools.json` official release records and uses the provided `xtensa-esp32s3-elf-gcc` driver alias. `IDF_PATH`, `IDF_TOOLS_PATH` and `XTENSA_GCC` are supported. No compiler flags are inferred from a generic Xtensa ABI. `-Dc-host-cc=clang` or `CC` selects the existing host compiler.

The local sandbox required `ZIG_GLOBAL_CACHE_DIR=/tmp/mimoc-global` and `--cache-dir /tmp/mimoc-cache` to keep cache writes in permitted directories. This is an environment constraint shared by the original build, not a C backend workaround.

## Verification ABI and reference view

`src/c_backend_smoke.zig` exports only:

```c
void mimoc_ui_smoke_init(void);
void mimoc_ui_smoke_step(uint32_t now_ms, uint32_t input_mask);
uint32_t mimoc_ui_smoke_render(uint8_t *framebuffer, size_t len);
```

The header is `integration/c_backend/smoke.h`. This is a verification ABI, not the production API. Render writes exactly the caller-owned 1024-byte, SSD1306 page-LSB Mono1 image. A null pointer or a buffer shorter than 1024 bytes returns 1 without writing; success returns 0. Init must precede use. A single fixed global instance owns Runtime(32 nodes, 4 animation tracks), selected slot, knob value and scroll offset. No heap, external application pointer, Zig slice or Zig struct crosses this C ABI.

Input bits 0–5 mean Up, Down, Left, Right, Activate, Back, applied in that order; zero mask only advances time. The reference is a small CONTACTS-style composition of the existing typed Ui, bitmap text, border/divider, focusable list, clipping/scroll, tuner and knob. Tuner indicator, knob indicator and scroll content use the existing 250 ms animation tracks. The reference avoids coupling the probe to the Desktop mock's platform modules while exercising the same reusable embedded widgets/rendering implementation.

`integration/c_backend/compare.c` links a native Zig object with a host-C-compiled object generated from the **same Zig entrypoint**. Only the generated object's three public verification symbols are renamed by compiler `-D` flags so two independent fixed states can coexist. Generated C is never edited. The driver supplies identical inputs/times and compares all 1024 bytes after every frame. On mismatch it reports case, frame number, time, input mask, first byte index, first differing pixel coordinate and both byte values. It also checks buffer canaries and invalid/null buffer handling.

The 2060 comparisons include initial state, focus right/down, selection/scroll retargeting, animation at 0/100/250/500 ms, Back/reset, time wrapping across UINT32_MAX, reinitialization and 2048 deterministic PRNG input/tick frames (seed `0x4d494d4f`). **All bytes matched in every frame; 1717 visible frame changes** prevent an accidentally static scene from satisfying the test. Hashes are not used as the equality oracle.

## Stage A measurements and commands

| Item | Observed result |
| --- | --- |
| Upstream Zig | 0.17.0; executable `/Users/mimoc/.zvm/0.17.0/zig` |
| Native/host-C ABI | aarch64-macos.27.0…27.0-none |
| Host compiler | Apple Clang 21.0.0 (clang-2100.3.34.2) |
| Generated host C | 330,828 bytes / 9,390 lines |
| Generated host C object | 26,296 bytes (file size) |
| Comparison executable | 86,152 bytes (file size, both implementations + C driver) |
| Equality | 2060 × 1024 bytes exact equality |
| Compiler warnings | 24 unused declarations/variables/parameters; no compile/link errors |

These file sizes are compiler/target/probe-specific, not ESP32 firmware Flash/RAM estimates. `report.json`, `zig-env.txt`, compiler logs and `equivalence.log` are emitted in the output directory printed by each check. `c-backend-host` installs the host records to `zig-out/c-backend/host` for review.

Equivalent direct generation commands (the build system controls cache/output paths):

```sh
zig build-obj src/c_backend_smoke.zig -O small -ofmt=c -femit-bin=mimoc_ui.c
zig build-obj src/c_backend_smoke.zig -O small -femit-bin=mimoc_ui_native.o
```

The build's target query has `.ofmt = .c`, which selects upstream `-ofmt=c`. `zig.h` is referenced from the **same compiler distribution's lib directory** for compilation and copied to build output by `emit-c`; no copy is vendored as source. Equivalent host compile/link/run commands:

```sh
clang -std=c11 -O2 -Wall -Wextra -I "$ZIG_LIB" \
  -Dmimoc_ui_smoke_init=c_mimoc_ui_smoke_init \
  -Dmimoc_ui_smoke_step=c_mimoc_ui_smoke_step \
  -Dmimoc_ui_smoke_render=c_mimoc_ui_smoke_render \
  -c mimoc_ui.c -o generated.o
clang -std=c11 -O2 -Wall -Wextra -Werror \
  integration/c_backend/compare.c mimoc_ui_native.o generated.o -o compare
./compare
```

Here `ZIG_LIB` denotes the installation's lib directory recorded by `zig env`, not a new source dependency.

### Warnings and runtime boundary

A strict `-Wall -Wextra -Werror` exploratory compile rejects unused artifacts emitted by upstream, not semantic/type/ABI errors on the host. The reproducible test retains `-Wall -Wextra` and records warnings rather than suppressing them. The handwritten driver itself uses `-Werror`.

- Eight warnings originate in `zig.h`: unused `res_is_signed`/`is_signed` parameters, `fixup`, and the `lhs_bytes` temporaries in `zig_big_shls_builtin` expansions.
- Sixteen originate in generated C: thirteen unused assigned temporaries in Runtime/render/Ui helper lowering and three unused constants (`builtin_output_mode`, the Ui scope key, and the error-name table).
- Warning categories are `-Wunused-parameter`, `-Wunused-variable`, `-Wunused-but-set-variable`, and `-Wunused-const-variable`. Full locations are in `host-generated.log` (generated line numbers may change with compiler/module naming).

Core Zig remains `std only`, without an allocator, libc link request or platform imports. Both Zig compilation paths set `link_libc = false`. The host comparison **harness** links host libc for diagnostics and memory operations. Clang's generated UI object has only `_bzero` and `_memcpy` as undefined symbols in this experiment, and no allocator, OS/thread or Zig runtime symbol. C lowering includes distribution `zig.h`, which includes standard C headers and exposes compiler helpers. A future freestanding final link must provide compiler-emitted memory primitives; ESP-IDF normally has a C runtime, but that link/runtime audit was not performed here. Stage B's failure prevents asserting absence of further Xtensa helper dependencies.

## Stage B: actual compiler boundary

Official tools were already installed under PlatformIO package directories; the compiler source provenance is Espressif's `crosstool-NG`, matched against IDF's own tools manifest. No IDF-managed `.espressif` installation or PATH compiler was initially present.

| Existing SDK/tool pair | Result |
| --- | --- |
| ESP-IDF 6.0.1 / GCC 15.2.0 (`esp-15.2.0_20251204`) | Same host C: 19 ABI assertion failures; Xtensa regeneration: 4; minimal reproducer: 4 |
| ESP-IDF 5.5.3 / GCC 14.2.0 (`esp-14.2.0_20251107`) | Xtensa regeneration: same 4 ABI assertion failures |

`integration/esp32s3-c-backend/CMakeLists.txt` is an object-only harness. It consumes the unmodified SDK's `tools/cmake/toolchain-esp32s3.cmake`. `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` keeps compiler detection from requiring a firmware executable. IDF 6 defers architecture options to `components/soc/project_include.cmake`; the harness selects the ESP32-S3/Xtensa/GCC config booleans and includes that **official file** to populate the response files. No manually guessed ABI/ISA flags are inserted. IDF 5's toolchain directly supplies its flags.

The observed IDF 6 response-file flags are:

```text
-mlongcalls
-fno-builtin-memcpy
-fno-builtin-memset
-fno-builtin-bzero
```

IDF 5 additionally supplies `-fno-builtin-stpcpy -fno-builtin-strncpy`. The harness's own language/diagnostic/optimization options are `-std=c11 -Os -Wall -Wextra`.

Equivalent command for the IDF 5 diagnostic regeneration:

```sh
zig build-obj src/c_backend_smoke.zig -O small -ofmt=c \
  -target xtensa-freestanding -mcpu generic -femit-bin=mimoc_ui.xtensa.c
xtensa-esp32s3-elf-gcc -I "$ZIG_LIB" -mlongcalls \
  -fno-builtin-memcpy -fno-builtin-memset -fno-builtin-bzero \
  -fno-builtin-stpcpy -fno-builtin-strncpy -std=c11 -Os -Wall -Wextra \
  -c mimoc_ui.xtensa.c -o mimoc_ui.o
```

The build executes CMake/Ninja instead of this handwritten invocation and retains `compile_commands.json` and the expanded IDF response flags in `report.json`. The unified official `xtensa-esp-elf-gcc` package supplies the SDK-selected `xtensa-esp32s3-elf-gcc` driver. GCC is responsible for ESP32-S3 instruction selection; Zig generates C only. Upstream 0.17's Xtensa model list has `esp32`, `esp8266`, `generic`; attempting `-mcpu esp32s3` is rejected. The generic and esp32 C outputs had the same ABI assertions. No fork was introduced to add an S3 CPU model.

### Two distinct ABI blockers

1. **Identical Stage A artifact:** host C embeds 64-bit pointer/long sizes, slice/Runtime layout constants and validation assertions. Xtensa uses 32-bit pointers. The same generated file therefore fails as expected. Generated C is a **target-specific artifact**, not an ABI-neutral source distribution. It must normally be regenerated from the same Zig source for each ABI. We tested the literal same-file requirement and recorded FAIL; a regenerated file is not substituted as a purported Stage B PASS.
2. **Xtensa regeneration:** 32-bit pointer and Core layout assertions now match, but four primitive alignments still differ:

| Type | Upstream Xtensa C output size/alignment | Official ESP32-S3 GCC size/alignment |
| --- | --- | --- |
| pointer | 4 / 4 | 4 / 4 |
| signed long long | 8 / 4 | 8 / 8 |
| unsigned long long | 8 / 4 | 8 / 8 |
| long double | 8 / 4 | 8 / 8 |
| double (`zig_f64`) | 8 / 4 | 8 / 8 |
| fixed-width uint64_t | 8 / 8 | 8 / 8 |

`abi_probe.c` compiles successfully with each official GCC and exports a ten-u32 size/alignment array. Espressif objcopy extracts `.rodata`; the script verifies/records those values without executing Xtensa instructions. Thus the ABI values are measured from the actual compiler, rather than inferred from an unrelated architecture.

The installed upstream `lib/std/Target.zig:cTypeAlignment` caps C primitive alignments for `.xtensa`/`.xtensaeb` at 4. Its fixed-width integer/max-int alignment logic permits 8, explaining why the `uint64_t` assertion passes while `c_longlong`/`double` checks fail. `zig.h` reports the failing assertions; the evidence identifies the upstream target/emitter ABI expectation, rather than a mimoc-ui construct or a malformed renderer replacement.

`integration/esp32s3-c-backend/minimal.zig` reproduces the issue without importing `std` or Core:

```zig
pub export fn mimoc_abi_minimal(value: u32) u32 {
    return value +% 1;
}
```

Its C output is 3,624 bytes / 52 lines and still contains those four failing primitive assertions, despite using only a u32 argument/result. The representative failure is:

```c
zig_static_assert(sizeof(signed long long) == 8 &&
                  zig_alignOf(signed long long) == 4, "abi mismatch");
```

The compiler stops before a UI object is generated. **ESP32-S3 mimoc UI object size: unavailable (no object); not zero.** Only the independent C ABI measurement object exists. No firmware is linked, so Xtensa runtime dependencies and execution equivalence remain unverified.

### Workaround decision

No Core source change was necessary for Stage A. There is no identified Zig UI construct to simplify for the Stage B blocker: even one scalar function fails. Removing ABI assertions, rewriting generated C, pretending another architecture is Xtensa, adding a handwritten duplicate renderer or patching the installed compiler would weaken the validation and violate the purpose of the upstream-only test. None was done.

A proper next step is an upstream target ABI correction or an upstream emitter fix, accompanied by a test against Espressif's measured ABI. Only after an official compiler containing that correction should the Xtensa-generated file be recompiled and its undefined-symbol/layout/runtime behavior reviewed. That work is outside this fixed-version experiment. No upstream issue was posted from this session; the minimal reproducer is ready for a separately authorized report.

## Maintenance recommendation and proposed compatibility policy

The architecture remains attractive: one Zig source implementation, fixed storage, declarative views, caller-owned framebuffer, target-specific generated artifacts and vendor C compilers. Stage A provides substantial evidence that current Core rendering/navigation/animation semantics survive C lowering. It does **not** prove an ESP32-S3 library can currently be operated with stock 0.17.0.

For the exact constraints tested here the answer is **NO-GO today**. Long-term adoption requires maintaining native-vs-C execution checks and real vendor compile gates, retaining ABI assertions, pairing `zig.h` with the exact compiler release and regenerating per target. Pinning upstream releases is still necessary even when there is no compiler fork; C backend compatibility and vendor ABI models must be checked on every upgrade. The remaining native Xtensa ABI issue must be resolved upstream before claiming operational viability.

A **review guideline plus CI**, rather than a permanently frozen language subset in README, is worthwhile:

- Integer/fixed-point arithmetic, bounded arrays, slices, pointers, structs, enums, tagged/packed unions, comptime/generics, switches and loops are natural Core choices. The exercised embedded path lowers without source changes; new features still need tests.
- Review atomics, vector/SIMD, threadlocal, inline assembly, architecture-specific builtins, OS APIs, libc imports and allocators before introducing them into Core. This probe has not established their C-backend/vendor support.
- Keep platform functionality outside Core, keep exported C boundaries to explicit scalar/pointer widths, and do not depend on generated internal struct layout as an external API.
- Treat ABI assertions and vendor compile failures as correctness signals. A missing compiler or a failure must remain nonzero, not a silently skipped portability success.

No existing CI configuration was present. `.github/workflows/c-backend.yml` now downloads the official upstream Zig 0.17.0 release using Zig's published index and checks its SHA256, then runs native/RV32 checks and host C compile/link/run equality on Linux. It does not install ESP-IDF or any Xtensa fork. This workflow was added and reviewed locally; a GitHub runner execution was not performed in this session. Official release metadata: [Zig download index](https://ziglang.org/download/index.json). C backend header coupling is also described in the [upstream zig.h issue](https://github.com/ziglang/zig/issues/13528).

Existing Debug and ReleaseSmall test suites, RV32 `check-embedded`, and macOS simulator/Studio/Desktop installation builds pass. Core source and existing application APIs were unchanged by this experiment.

## Exact local zig env

```text
.{
    .zig_exe = "/Users/mimoc/.zvm/0.17.0/zig",
    .lib_dir = "/Users/mimoc/.zvm/0.17.0/lib",
    .std_dir = "/Users/mimoc/.zvm/0.17.0/lib/std",
    .global_cache_dir = "/tmp/mimoc-global",
    .version = "0.17.0",
    .target = "aarch64-macos.27.0...27.0-none",
    .env = .{
        .ZIG_GLOBAL_CACHE_DIR = "/tmp/mimoc-global",
        .ZIG_LOCAL_CACHE_DIR = null,
        .ZIG_LOCAL_PKG_DIR = null,
        .ZIG_LIB_DIR = null,
        .ZIG_LIBC = null,
        .ZIG_BUILD_ERROR_STYLE = null,
        .ZIG_BUILD_MULTILINE_ERRORS = null,
        .ZIG_BUILD_SUMMARY = null,
        .ZIG_VERBOSE_LINK = null,
        .ZIG_VERBOSE_CC = null,
        .ZIG_VERBOSE_CMD = null,
        .ZIG_DEBUG_CMD = null,
        .ZIG_IS_DETECTING_LIBC_PATHS = null,
        .ZIG_IS_AVOIDING_CALLING_ITSELF = null,
        .NIX_CFLAGS_COMPILE = null,
        .NIX_CFLAGS_LINK = null,
        .NIX_LDFLAGS = null,
        .C_INCLUDE_PATH = null,
        .CPLUS_INCLUDE_PATH = null,
        .LIBRARY_PATH = null,
        .CC = null,
        .PKG_CONFIG = null,
        .NO_COLOR = "1",
        .CLICOLOR_FORCE = null,
        .XDG_CACHE_HOME = null,
        .LOCALAPPDATA = null,
        .HOME = "/Users/mimoc",
        .PROGRAMDATA = null,
        .HOMEBREW_PREFIX = "/opt/homebrew",
    },
}
```
