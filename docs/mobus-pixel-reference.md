# Mo-Bus Product UI Legacy Reference

## Result and baseline

**Product core coverage: PASS, 29/29 required P0 surfaces.** The catalog has
**196 scenarios: 191 VERIFIED, 5 SOURCE-FAITHFUL, zero UNVERIFIED P0 scenarios.**
Each VERIFIED frame exactly matches independently executed original C++:
128×64, page-LSB, **1,024 bytes / zero differing pixels**. All entries are
rendered 100 times for determinism and compared between Native Zig and
upstream Zig 0.17.0 generated C. Candidate seeds have identical pixels.

The single source baseline is `moribit/Mobus_ESP_IDF`, `fix/after-release`,
**`4b6705f62160e1849cd161f9515d507df90d23d2`**. On 2026-10-10 the remote branch
and local `origin/fix/after-release` resolved to this SHA. All investigation
and capture use a temporary `git archive`, not the production working tree.
That repository was not changed.

Previous baseline: `94873ec79bd70d2f38040d173f2f9c89853b5734`. Important changes
include Ehagaki's five-entry left/right menus, rectangle-fill selection,
dotted selection perimeter, selection/text-placement stages, clear dialog,
and CanvasText ASCII header override. Therefore **all existing 42 VERIFIED
frames were independently recaptured at the new SHA**. Their 1,024-byte
contents are unchanged. All 191 goldens and assets now use one baseline;
there is no mixed-commit golden set.

| Feature | VERIFIED | SOURCE-FAITHFUL | Required P0 coverage |
|---|---:|---:|---|
| MENU | 4 | 0 | Complete |
| CONTACTS | 6 | 0 | Complete |
| QSP | 21 | 1 | History, composer, delivery |
| CQ | 14 | 0 | Connection, incoming, active |
| SYNTH | 27 | 0 | Grid, header, editors, slots, dialogs |
| EHAGAKI | 60 | 2 | Root, browse, text, canvas, menus, overlays, lifecycle |
| SETTINGS | 3 | 0 | Menu/list |
| WI-FI | 8 | 0 | List, password, connection/status |

The other 50 entries cover Open Chat, dialogs, Profile, TRA/step Composer,
Text/Status, Factory Setup, Firmware Info, Realtime Talk and basic Draw.
See the [surface/scenario matrix](mobus-product-ui-coverage.md),
[product flows](mobus-product-ui-inventory.md), and
[consistency audit](mobus-ui-consistency-audit.md). Coverage refers to major
surfaces, not every reachable edge case or optional application.

## Independent ground truth

The diagnostic `frame ROW` path thresholds Sprite pixels before panel
conversion. It cannot certify gray ticks. The host adapter instead invokes
original renderer headers and **verbatim extracted facade/helper functions**
with fixed final render arguments. Screen classes, network, audio, NVS,
playback tasks and FreeRTOS are not executed. Small host memory shims only
convert application string types; they do not change rendering.

`tools/mobus_product_fixtures.py` emits both C++ adapter calls and typed Zig
fixtures/catalog entries from the same fixed arguments. Original QSP wrapping
builds the original ViewState; Zig separately implements wrapping/drawing.
Finished screens are never used as the Zig renderer. Synth uses masks,
accents, selection, enabled tracks, header and dialog arguments. Ehagaki uses
a deterministic 122×58 caller-owned canvas at (3,3), with actual menu/stage
arguments. Browse mine/public differences are filters, not invented styling.

Capture uses actual RGB332 LGFX Sprite and `Panel_SSD1306`/`Panel_HasBuffer`,
rotated by 2 as in production. Only transport hooks are replaced. Panel fills
and presentation x offsets are retained, including shifted QSP limit feedback.
Output is normalized to logical coordinates. Existing **LovyanGFX 1.2.25** is
pinned by complete source hash in the
[manifest](../examples/mobus/reference/golden/manifest.json), not version alone.

Clock inputs are fixed: 500,000 µs; UTC 2026-06-01 12:34:56. Reveal fixtures
specify fixed elapsed values. Host capture uses Apple Clang and installed
SDL2 without creating a window. Two original uint32→uint16 color-truncation
warnings remain; source is not patched to silence them.

## Fonts and drawing semantics

Original rasterization is converted per glyph, retaining advance, measurement,
fontHeight, ink/opaque masks, and separate drawString/print origins. There are
**2,628 glyph records and 935 unique masks**. Baseline/offset behavior is encoded
relative to the original origin; no approximate font is substituted.

| Font | Captured metrics / use |
|---|---|
| MobusCustom7 | Height7; menu, ASCII history/settings, Synth, canvas menus |
| Font2 | Height16, variable advance; English UI, Contacts, headers |
| MisakiGothic8 | Actual height7; original Katakana subset and missing-glyph behavior |
| lgfxJapanGothic_8 | Actual height9; Ehagaki browse Japanese text |
| lgfxJapanGothic_12 | Actual height13; talk/input Japanese |
| U8g2B12Japanese1 | Height12; available Katakana, original selector falls back to JapanGothic12 when missing |

Canvas 5×7/3×5 glyph columns and Morse/romaji reveal tables are parsed from
original runtime assets. See [provenance](../examples/mobus/reference/provenance.md)
for source notices and IPA license. Font4/game GFX fonts remain outside P0;
Core contains none of these Mo-Bus font tables.

Existing integer Mono1 and opt-in `raster_compat` preserve Lovyan line,
circle, triangle and rounded-rectangle policies. Dotted selection perimeter,
bitmap blits, clipping, text datum, centering truncation and original UTF-8
width wrapping are preserved. Line lengths are counts; rect endpoints are
x+w−1/y+h−1. QSP outgoing inverts only the prefix. Synth retains all six tracks,
16 steps, accents, group dividers, disabled marks, selection and playhead.
No Mo-Bus-specific API or new primitive was added to Core this task.

Color is not reduced to “nonzero means white.” RGB565/RGB888 overloads,
RGB332 quantization, gamma and rotated Bayer phase are retained. Contacts
int 0xC618 quantizes to gray198 and dithers. Unsigned 0xFFFFu inverse-text
background can be cyan/gray179 while int 0xFFFF row fill is white. Other
0x7BEF/0x2104 patterns likewise use actual panel conversion. Original-frame
comparison tests these differences without beautifying them.

## Run and compare

```sh
zig build studio
# Click UI LAB, or press L; select QSP / CQ / SYNTH / EHAGAKI directly.
zig build mobus-reference-snapshot -- --list
zig build mobus-reference-snapshot -- --coverage
zig build mobus-reference-snapshot -- qsp/mixed --raw > qsp.raw
zig build mobus-reference-snapshot -- synth/grid-playing --pbm > synth.pbm
zig build mobus-reference-diff -- --screen ehagaki/canvas-select-end \
  --expected examples/mobus/reference/golden/ehagaki-canvas-select-end.raw
zig build check-mobus-product-coverage
zig build check-mobus-reference
zig build check-mobus-reference-c
```

Raw: 1,024 bytes, byte `(y/8)*128+x`, bit `y%8`. PBM: P4 row-MSB. Diff reports
matching/different pixels, first coordinate/byte and mismatched bytes, writes
expected/actual/XOR PBM/raw under `zig-out/mobus-diff`, and fails for any pixel.

```sh
python3 tools/capture_mobus_reference.py \
  --repo /path/to/Mobus_ESP_IDF --lgfx /path/to/existing/LovyanGFX \
  --output /tmp/new-empty-staging-directory --verify
python3 tools/mobus_reference_inventory.py \
  --repo /path/to/Mobus_ESP_IDF --output /tmp/inventory
```

Capture downloads nothing; it requires the pinned commit, Clang, SDL2 under
`/opt/homebrew` and pinned LGFX. `--verify` checks input hashes, generated assets
and all 191 independent frames. Changed baselines require reviewing source
changes and recapturing the whole set; Zig output must never replace an oracle
just to pass. [Coordinate evidence](mobus-source-coordinates.md) and
[JSON inventory](mobus-source-inventory.json) cover all 22 screen source files.

## Studio / Candidate separation

UI Lab exposes eight direct P0 feature buttons and **Feature → Surface →
Scenario** navigation. Next Feature exposes supporting features; Next Surface
stays in the current feature; Up/Down cycles that surface's scenarios.
Left/Right/Enter changes Legacy, Candidate, 500ms alternate, XOR or side-by-side.
Inspector shows verification/differing pixels; hover shows x/y and both bits.
Lab reserves selector space: single preview uses3× logical scale (6× with the
2× window), side-by-side uses2×. Non-Lab retains1×/2×/4×. Presentation never
changes the128×64 framebuffer.

`reference/screens/` is divided by feature, with separate Ehagaki browse,
text, canvas and dialog modules. `design/` is unchanged and receives the same
Scenario/Fixture, seeded from Legacy. **All196 seeds have zero difference.**
The older interactive Mo-Bus demo remains separate. No typography, spacing,
header or selection cleanup was applied to Legacy.

## Regression and portability

Checks: `zig build test`, `test -Doptimize=small`, `check-embedded`,
`check-c-backend-host`, `check-mobus-reference`, `check-mobus-reference-c`,
coverage gate and simulator/Studio builds. Core retains **2,060×1,024 exact
frames**; reference C compares **196×1,024**, including SOURCE-FAITHFUL entries.
Standalone reference C compilation retains56 warnings in `compiler.log`;
undefined-symbol audit permits only memory primitives, not allocators,
platform functions or unexpected Zig runtime. Generated C/assertions are
untouched. All191 original frames/assets were independently regenerated with
`--verify`.

Reference uses fixed-capacity integer buffers, borrowed font masks and
caller-owned output: no heap, libc, OS, floating point or macOS fonts. The
same Candidate can follow the existing ESP32-S3 C-backend path. This task
proves host C equivalence, not firmware/ESP32 target integration.

## Technical exceptions and remaining scope

Five SOURCE-FAITHFUL entries (`text/offline`, `text/error`, `qsp/offline`,
`ehagaki/browse-offline`, `ehagaki/error-offline`) share one defect:
`kOfflineBitmap` has87 bytes but a24×30 draw requests90. Capture does not execute
the out-of-bounds final row. Reference draws29 defined rows and leaves the
unknown last row clear. They have no invented golden and are never VERIFIED.

Physical captures, persistent Sprite-state transition sequences, arbitrary
text and every edge case are outside fixed-fixture certification. Additional
P1 contact-action/settings/Draw-menu paths and P2 Watch/games remain explicit
in the matrix. These are local font/capture gaps, not structural constraints.
The29-surface P0 gate is satisfied for starting the separate Design System
phase while keeping Legacy fixed.
