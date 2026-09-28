# CH32V003 code size investigation

2026-09-28. This is a measurement and attribution report, not a change to the production renderer or UI behavior. The machine-readable results are in [ch32-size-matrix.csv](ch32-size-matrix.csv). The reproducible firmware variants live in `ch32-mimoc-ui/src/size_probe.zig`; run `sh tools/size-matrix.sh` from that repository. The script restores the normal, flashable build when it exits. Analysis images use a deliberately enlarged FLASH linker region and **must not be flashed**.

## 1. Measurement environment and method

| Item | Value |
| --- | --- |
| Host | macOS, Apple LLVM `llvm-size`/`llvm-nm` |
| Zig | 0.16.0 |
| Target | `riscv32-freestanding-eabi`, `generic_rv32+c+e-i` (RV32EC) |
| Optimization | `ReleaseSmall`, compiler runtime bundled, function/data sections and linker GC |
| Mimoc UI | `7e2574057b373321ad383847177e76aed77fb0f2` |
| ch32-mimoc-ui | `d561d8c213c1dbdf16efb636f645ab445aa2aec5` before the analysis files |
| ch32fun_zig | `d73ffaca67992208165911562cb773ac6163bf6e` |
| Reference capacity | 10 nodes, 0 animation tracks, SSD1306 page mode |

The unmodified reference was built twice with identical SHA-256 `496018b1f69ac16b354cadbd7e55f5aa1f9c1119784656283eb3c35b42ad7d0f`. The analysis-linker reference with unstripped symbols is also **16,184 B**, so symbol inspection does not change the measured flash image. All deltas below are linked-image deltas: dead-code elimination, inlining, alignment and shared helpers make them context dependent. A widget's delta is not its standalone object-code size.

The normal linker limits the firmware area to 16,320 B (`16 KiB − 64 B` user-data page). The analysis linker extends only the FLASH length to allow oversized comparisons. RAM remains 2 KiB. `firmware.bin` includes loadable `.data` initializers; `.bss` is RAM only. The linker merges `.rodata` into `.text`, so separate `.rodata = 0` below **does not** mean no read-only constants.

## 2. Current baseline and sections

| Build | `.reset` | vectors | `.text` including rodata | `.data` | `.bss` | Static RAM | `firmware.bin` | Flash headroom |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| HAL only V0 | 20 | 156 | 1,888 | 4 | 136 | 140 | **2,068** | 14,252 |
| Core + one Text V1 | 20 | 156 | 13,128 | 424 | 136 | 560 | **13,728** | 2,592 |
| Current reference | 20 | 156 | 15,584 | 424 | 136 | **560** | **16,184** | **136** |
| Current reference, 1 track | 20 | 156 | 16,664 | 564 | 136 | 700 | **17,404** | −1,084 |

V0 keeps the same startup, system timer, I²C SSD1306 initialization, page transfer, and loop but does not import Mimoc UI into a reachable code path. Its 136 B `.bss` includes the 128 B page buffer. V1 adds 11,660 B Flash and 420 B static RAM. The latter equals `@sizeOf(Runtime(10,0))`; the reference has 4 B other `.data`. The 16,184 B reference is 1,576 B larger than the V3 two-node high-level probe because it uses more widgets, input and application logic. The older 8-node/1-track reference of 13,844 B and 516 B RAM is **not** a controlled A/B comparison: the application and API changed as well as capacity.

## 3. Variant matrix and high-level API

All of these have `.data=424`, `.bss=136` and static RAM 560 B unless noted. V2 and V3 both draw one `Text("A")` and one 16×8 rectangle in a Stack. In chemu, their dumped 128×64 OLED images match on every one of the 64 rows after two million emulated instructions.

| Variant | Flash | Delta from previous relevant row | What changes |
| --- | ---: | ---: | --- |
| V0 HAL | 2,068 | — | Startup, I²C, SSD1306, page transfer |
| V1 Core + Text | 13,728 | +11,660 vs V0 | Low-level in-place builder, layout, Mono1, bitmap font, one Text |
| V2 low-level pair | 14,260 | +532 vs V1 | `begin/add/end/finishView`, Text + Rect |
| V3 high-level pair | 14,608 | **+348 vs V2** | `Ui(Id, config)`, typed IDs, ScopeGuard, `finish()` |
| Raw `u16` IDs | 14,608 | **0 vs V3** | Same high-level methods with `Ui(u16, config)` |
| `finishChecked()` | 14,576 | −32 vs V3 | Different error path; this is an optimization/layout effect, not a guaranteed saving |
| Diagnostics enabled, no screen name | 14,948 | **+340 vs V3** | Rich diagnostics compiled in |
| Diagnostics enabled with screen name | 14,968 | +360 vs V3 | Includes `SIZE_PROBE` string |

`rootId()`, `childId()` and `derive()` do not occur as standalone symbols in the reference; typed literal ID derivation is inlined/constant-folded. The high-level reference has one `Ui(main.Id, ...)` specialization, `Ui.add` 74 B, `Ui.beginNode` 274 B, and `Ui.collision` 56 B as named functions. The 348 B V2→V3 delta is the **whole API path**, including different builder/error/control flow; it cannot be assigned solely to identity or scope guards. The reference binary contains no rich diagnostic strings (`NodeCapacity`, `DuplicateId`, screen name, panic formatting) according to `strings` on `.bin`; DWARF strings in the unstripped ELF are not flash payload. Enabling diagnostics costs 340 B here, confirming that this is currently stripped from ReleaseSmall by default.

An isolated non-production experiment disabled only the high-level `Ui.collision` scan in a temporary source copy. V3 changed 14,608→14,504 B (−104 B); the real reference changed 16,184→16,072 B (−112 B). This is an **upper bound for that implementation**, not a safe optimization: `Runtime.finishView()` still rejects duplicate IDs, but the early `IdentityCollision` diagnostic and failure timing change. At 10 nodes, the high-level scan and final validation each perform at most `0+1+…+9 = 45` pair comparisons per rebuild. No cycle timing was measured. A behavior-preserving consolidation of the two checks needs a separate design and test.

An isolated runtime mixer probe using a page-derived variable compared the current rotate/XOR expression with a non-equivalent addition expression. Both linked at 2,088 B, equal to the dynamic-pixel probe. This **0 B observed delta** does not prove that the addition mixer is equivalent or universally free: the reduced output consumes only seven ID bits, and optimizer folding/inlining obscures the local instruction count. There is no basis to replace the current mixer or weaken collision behavior. A target-capable disassembler is required for a stronger instruction-count claim.

## 4. Widget incremental and cumulative cost

Each isolated widget row starts from V3 (14,608 B). It **adds** one widget to Text+Rect, so its delta includes first use of any helper or renderer primitive. Static RAM is 560 B for every row.

| Additional widget | Flash | ΔFlash |
| --- | ---: | ---: |
| Text (second) | 14,680 | +72 |
| Button | 14,696 | +88 |
| Checkbox | 14,696 | **+88** |
| Toggle | 14,932 | **+324** |
| Progress | 14,876 | **+268** |
| Icon | 14,712 | **+104** |
| Divider | 14,700 | +92 |
| Panel | 15,248 | +640 |
| Scrollbar | 14,944 | +336 |
| WrappedText | 14,708 | +100 |
| Tuner | 14,956 | +348 |
| Knob | 14,944 | +336 |
| List | 15,100 | +492 |
| ScrollView | 14,928 | +320 |
| Bitmap | 14,708 | +100 |

The cumulative Column screen uses the same configuration and adds widgets in order:

| Step | Flash | Marginal Δ | Static RAM |
| --- | ---: | ---: | ---: |
| C0 Text only | 14,484 | — | 560 |
| C1 + Checkbox | 14,608 | +124 | 560 |
| C2 + Toggle | 15,036 | +428 | 560 |
| C3 + Progress | 15,276 | +240 | 560 |
| C4 + Icon | 15,380 | +104 | 560 |

The C2 cost differs from the isolated Toggle cost because the prior screen and optimizer context differ. Summing independent deltas would be wrong. Source inspection shows repeated widget node creation and generated IDs, but the binary data above does **not** establish that extracting shared functions would reduce bytes; inlining may be smaller. Panel and List are the largest isolated additions, yet neither is required by the current tiny reference screen.

## 5. Renderer, font, layout and input

Direct renderer variants start from V0, bypassing the Runtime and its dynamic Node-kind dispatch. Their costs are relative to 2,068 B and are not additive:

| Direct use | Flash | Δ vs HAL |
| --- | ---: | ---: |
| Renderer init | 2,068 | 0 |
| Pixel | 2,088 | +20 |
| HLine | 2,104 | +36 |
| VLine | 2,148 | +80 |
| Line | 2,244 | +176 |
| Rect | 2,392 | +324 |
| FillRect | 2,196 | +128 |
| Bitmap | 2,204 | +136 |
| `font.draw("A")` | 3,708 | **+1,640** |
| Clip + pixel | 2,124 | +56 |

The linked V1 Text-only Runtime still has `Renderer.bitmapFormat` 242 B, `Renderer.line` 226 B, `Renderer.circle` 176 B, `wrap.Iterator.next` 422 B and `font.decode` 310 B. This is evidence that the dynamic Node-kind renderer and layout pull in paths unused by this particular screen; it is a stronger lead than simply blaming the high-level API. `font.glyph` is 1,206 B of linked code. There is no separately attributable glyph-table `.rodata` section because rodata is merged into `.text`. UTF-8 decoding and wrapping remain valid framework features; a Tiny specialization should be considered only after preserving the common Core API and measuring the emitted binary.

Layout-only variants gave Column 14,604 B, Row 14,608 B and Column with padding/spacing/alignment 14,608 B, against Stack 14,608 B. Differences of 0 to −4 B reflect compiler context; they **do not** establish that Row/Stack code was entirely stripped. In the current linked reference, `layout.place` is 972 B and `layout.measure` is 952 B. Input probes add hardware button setup as well as Core input: focus traversal with Down is 15,192 B (+584 vs V3); Button activation with typed-ID comparison is 15,096 B (+488 vs V3). These are not pure `Runtime.action()` costs because they also introduce HAL button code and, for activate, a Button node.

## 6. Animation capacity

| Same screen | 0 tracks | 1 track | ΔFlash | Δ static RAM |
| --- | ---: | ---: | ---: | ---: |
| C4 probe | 15,380 | 16,572 | **+1,192** | **+140** |
| Real reference | 16,184 | 17,404 | **+1,220** | **+140** |

For the real reference, `.text` rises 1,080 B and `.data` rises 140 B. The latter is one `Track` (36 B) plus 10 previous `{id, Rect}` entries and bookkeeping/alignment. Explicit animation specifications on the C4 probe add only 4 B beyond enabling one track (16,572→16,576). The current 0-track binary already contains named `Runtime.update` (646 B), `Runtime.presentationAt` (256 B), and `animation.interpolate` (172 B); presence alone does not show that the full tracking path executes when capacity is zero. The 1-track real reference exceeds the 16,320 B flash area by **1,084 B**. A 1-track build cannot be made deployable by node-count tuning alone without measuring a changed application.

## 7. Largest linked code and unexpected helpers

The following are unique-address symbols in the unstripped **same-size** real reference ELF. They are not a partition of all Flash: inlined code appears inside callers, anonymous constants lack useful names, and symbol aliases must not be double-counted.

| Symbol | Bytes |
| --- | ---: |
| `main.main` (inlined orchestration included) | 3,182 |
| `main.rebuild` (inlined screen code included) | 1,272 |
| `font.glyph` | 1,206 |
| `layout.place` | 972 |
| `layout.measure` | 952 |
| `Runtime.update` | 646 |
| `__udivmoddi4` | 454 |
| `wrap.Iterator.next` | 422 |
| `compiler_rt.udivmod.divwide` | 400 |
| `hal.i2c.writeBlocking7bit` | 368 |
| `hal.ssd1306.nextPage` | 340 |
| `__udivsi3` | 312 |
| `font.decode` | 310 |
| `Ui.beginNode` | 274 |
| `Runtime.presentationAt` | 256 |
| `Renderer.bitmapFormat` | 242 |
| `Renderer.line` | 226 |
| `Builder.append` | 210 |
| `font.draw` | 206 |
| `Renderer.pixel` | 190 |
| `__muldi3` | 182 |
| `Renderer.circle` | 176 |
| `animation.interpolate` | 172 |
| `Renderer.rect` | 132 |
| `Rect.intersect` | 126 |

RV32EC has no hardware multiply/divide here. Unique linked arithmetic helpers total approximately **1,556 B**: `__udivmoddi4` 454, its wide-division helper 400, `__udivsi3` 312, `__muldi3` 182, `__divdi3` 80, `__divsi3` 50, `__umodsi3` 44, `__mulsi3` 24 and `__udivdi3` 10. These are a real optimization lead, but some originate in page timing or HAL as well as UI geometry/text. V0 has only tiny memcpy/memset helpers and none of these arithmetic helpers; V1 adds the set. Exact call-site attribution needs RISC-V disassembly or IR inspection. Apple `llvm-objdump` cannot disassemble this RISC-V ELF, and Zig 0.16 `zig objdump` reported `TODO dump elf file` here. Consequently variable rotate instruction counts, concrete call sites, and precise per-function stack frames are **unmeasured**.

No named `std.debug`, `std.fmt`, `std.unicode`, panic-formatting, or rich diagnostics routines were found in the linked reference ELF. This is not proof that UTF-8 behavior is absent: `font.decode` and `wrap.Iterator.next` are present under their application symbols. `@tagName` does not leave widget names in the production `.bin` under this configuration. There is only one instantiated `Ui(main.Id, config)` in the real reference symbol list, so **no duplicate typed-ID specialization was observed in this firmware**. Multiple ID types in a future app may differ; no blanket conclusion is warranted.

## 8. RAM and stack

The RV32 `@sizeOf` export in `src/footprint_embedded.zig` gives `Node=40 B`, `Runtime(10,0)=420 B`, `Runtime(10,1)=560 B`, `Ui(u16,10,0)=40 B`, `Ui(u16,10,1)=40 B`, `Track=36 B`. The frequently quoted `Node=48 B` is the 64-bit host ABI size and must not be used for CH32V003 budgeting. `Ui` is a temporary builder value, not part of `.data + .bss` in the reference. The real reference leaves `2048 − 560 = 1488 B` after static allocation; the 1-track version leaves 1348 B. Those numbers exclude live stack, interrupt stack usage, hardware driver locals and any other dynamic storage. **Actual stack peak/watermark is unmeasured.** No claim of safe total RAM use follows from static RAM alone.

## 9. Optimization candidates, with evidence and risk

| Class | Candidate and measured current cost | Expected saving / confidence | RAM, API and behavior impact |
| --- | --- | --- | --- |
| A: low risk, high impact if verified | Find unintended RV32 64-bit arithmetic. Wide divide/multiply helpers account for up to 1,126 B of the 1,556 B arithmetic-helper set. | **200–800 B estimate, low confidence** until call sites are identified. | Prefer mathematically equivalent narrow calculations; no API change. Watch overflow semantics and code-size regressions. |
| A: low risk, conditional | Keep rich diagnostics out of ReleaseSmall. The explicit diagnostics-on probe costs +340 B; normal reference contains no rich strings. | **0 B currently**; regression guard rather than immediate saving. | No RAM/API/behavior change in current build. |
| B: medium risk | Reduce dynamic renderer/font paths pulled in by Text-only V1. Examples already linked: wrapping 422 B, UTF-8 decode 310 B, bitmapFormat 242 B, circle 176 B. | **300–700 B estimate, low confidence**; shared dispatch and helpers prevent adding named sizes. | A compile-time capability/dispatch approach could preserve public API, but must retain full Core behavior for normal profiles and test page equivalence. |
| B: medium risk | Consolidate high-level collision checking and `Runtime.finishView` duplicate validation. Temporary removal of the high-level scan saves 112 B on real reference. | **50–112 B estimate, medium confidence** if the same diagnostics/error behavior can be retained. | No additional RAM intended; error timing and type must remain compatible. |
| B: medium risk | Examine high-level V2→V3 code path and generic inlining. Whole measured delta is 348 B; typed enum itself is 0 B in this screen. | **0–150 B estimate, low confidence**; optimization may move bytes elsewhere. | Keep existing high-level API and focus/identity semantics. |
| C: architectural trade-off, defer | Tiny-specific text/render capabilities or animation subset. Text Core first-use is +11,660 B; one animation slot is +1,220 B Flash/+140 B RAM in real reference. | Potentially larger, **not quantified as safe saving**. | Can alter feature availability or behavior. Do not implement before A/B candidates and page-render tests. |

The numerical ranges labelled *estimate* are not demonstrated savings and must not be added together. The currently demonstrated behavior-preserving saving is **0 B**; the 112 B collision experiment deliberately changed diagnostic behavior. A realistic no-API-change opportunity is plausibly several hundred bytes, with the arithmetic and dispatch investigations first, but that remains a hypothesis until isolated linked-image comparisons succeed.

### Recommended order

1. **Attribute the 1,556 B arithmetic-helper set to call sites**, starting with 64-bit divide/multiply. Acquire a RISC-V-capable disassembler or emit LLVM IR; change only proven wider-than-needed arithmetic and compare the real 16,184 B image.
2. **Investigate why a one-Text Runtime links wrapping, UTF-8 decode and unused-looking renderer primitives.** Seek dead stripping or small shared dispatch changes that keep the public API and deterministic full/page rendering identical.
3. **Test a behavior-preserving duplicate/collision validation consolidation.** The measured upper bound is 112 B on the real reference; preserve `IdentityCollision`/`DuplicateId` semantics and Studio diagnostics.
4. Only then revisit high-level code generation or Tiny feature profiles. Typed IDs and ReleaseSmall diagnostics are not current size problems; disabling them would be a poor first move.

The immediate 136 B Flash headroom is too narrow for normal evolution. The first optimization should target unnecessary generated code, not remove Developer Friendly APIs or widgets before attribution.

## 10. Direct answers to the investigation questions

| Question | Answer |
| --- | --- |
| Q1. No Mimoc UI | **2,068 B** HAL/page-transfer baseline. |
| Q2. Core + Text | **+11,660 B**, resulting in 13,728 B. |
| Q3. Low-level → high-level, same screen | **+348 B**, 14,260→14,608 B; OLED output identical in chemu. |
| Q4. Checkbox / Toggle / Progress / Icon | Isolated additions to V3: **+88 / +324 / +268 / +104 B**. Cumulative additions after C0: **+124 / +428 / +240 / +104 B**. |
| Q5. 0→1 animation track | **+1,220 B Flash, +140 B static RAM** on the real reference. |
| Q6. Largest code/data | `main.main` 3,182 B (includes inlining), `main.rebuild` 1,272 B, `font.glyph` 1,206 B; `main.runtime` data 420 B and SSD1306 page buffer 128 B. |
| Q7. Unexpected Zig std code | No named formatting/debug/panic routines or diagnostic strings in the binary. **1,556 B** of RV32 software arithmetic helpers are linked; UTF-8/wrap code is also present. |
| Q8. Generic specialization duplicates | **None observed** for `Ui`: the current app instantiates one `Ui(main.Id, config)`. A multi-ID-type app was not measured. |
| Q9. Safe no-API/no-behavior saving | **0 B demonstrated so far**. Arithmetic narrowing **200–800 B estimated** and render dispatch **300–700 B estimated**, both require proof. Removing the collision scan saves 112 B but changes diagnostics. |
| Q10. First three investigations | (1) arithmetic-helper call sites, (2) Text-only renderer/font reachability, (3) duplicate collision scans. The measured sets above, rather than an assumption that typed IDs are expensive, determine this order. |
