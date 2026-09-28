# Milestone 7 progress: CH32V003 integration

## Implemented

`integration/ch32v003` is an independent Zig package that depends on `mimoc-ui` and `ch32fun_zig`; neither dependency is imported by Mimoc UI Core. The same package is installed as `ch32fun_zig/examples/mimoc_ui` in the sibling checkout. Its adapter uses the actual HAL `firstPage()` / `nextPage()` picture loop and renders directly into `fun.ssd1306.buffer`, the HAL's 128-byte page storage. The application calls `runtime.update(now_ms)` once before drawing all eight pages. A PD1 button edge advances focus through CHAT, CQ, and EHAGAKI; a one-track indicator animates between selections.

The sample uses `Runtime(.{ .max_nodes = N, .max_animations = A })`, no allocator, no libc, no full framebuffer, and a clock derived from wrapping SysTick cycle differences. The firmware builds against the CH32V003 RV32EC target and its 2KB RAM / 16KB Flash linker script.

## Static build measurements

Zig 0.16 ReleaseSmall, `llvm-size -A` on the actual linked firmware in the `ch32fun_zig/examples/mimoc_ui` checkout. `.data + .bss` is the static RAM load; Flash includes `.reset`, `.vector_table`, `.text`, and `.data` load image. The linker reserves 64B of the 16KB Flash for user data.

| Nodes / tracks | Runtime bytes, RV32 | `.data` | `.bss` | Static RAM | RAM left for stack and other runtime use | Flash image |
|---|---:|---:|---:|---:|---:|---:|
| 8 / 1 | 380B | 380B | 136B | 516B | 1532B | 12068B |
| 12 / 1 | 540B | 540B | 136B | 676B | 1372B | 12228B |
| 16 / 1 | 700B | 700B | 136B | 836B | 1212B | 12388B |
| 16 / 4 | 808B | 808B | 136B | 944B | 1104B | 12504B |

The 128-byte HAL page buffer is included in `.bss`, not added a second time. A Node occupies 40B on RV32; each additional four nodes costs 160B. The in-place builder is temporary stack storage (24/32/40B for 8/12/16 nodes) and is not included in static RAM. The preferred initial hardware configuration is **8 nodes / 1 track**, leaving the largest margin. The complete app currently uses exactly eight nodes.

## Verification and gate

The integration builds and links for all four configurations. The firmware image fits the CH32V003 linker limits. The Mac's USB inventory did not expose a connected CH32V003 board or programmer, so no flash or physical display/input test was performed. Stack high-water, layout/update/render cycle counts, full eight-page frame time, and actual FPS have **not** been measured. The RAM-left column is capacity after static allocation, not a measured free-stack guarantee.

Milestone 7 is therefore **not complete**. Hardware measurements and visual/input confirmation are required before starting Milestone 8. Milestone 8/9 integration remains gated in the requested sequence.
