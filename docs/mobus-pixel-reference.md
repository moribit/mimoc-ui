# Mo-Bus pixel reference

## Baseline and result

Source of truth: `moribit/Mobus_ESP_IDF`, branch `fix/after-release`, commit
**`94873ec79bd70d2f38040d173f2f9c89853b5734`**, confirmed against the remote
branch at the start of this work on 2026-10-10. The local checkout contained
uncommitted changes, so all renderer/font/screen investigation and capture
used `git archive` of this SHA in a temporary workspace. The Mo-Bus working
tree was not modified.

**Phase 1 feasibility: PASS.** MENU, CONTACTS, OPEN CHAT, SETTINGS and CONFIRM
DIALOG: 19 scenarios, each **1024 bytes exact match / zero pixel mismatch**
against independently executed original C++ renderers. No captured screen is
used as the implementation of the Zig renderer.

Phase 2 currently adds Profile, TRA, Ehagaki menu, Room Selector, step
Composer, Wi-Fi, Factory Reset and Text/Status. The rendered catalog contains
44 scenarios: **42 VERIFIED**, **2 SOURCE-FAITHFUL**. Every scenario is rendered
100 times in the determinism test. The remaining inventory below is explicitly
UNVERIFIED; the representative five-screen proof does not certify every
application state or the physical panel.

VERIFIED means equal to original source-renderer software output through the
actual installed LovyanGFX SSD1306 conversion. It does not mean a physical
device capture was performed. SOURCE-FAITHFUL means defined source behavior
is reproduced with a documented reference uncertainty. UNVERIFIED means no
completed port/oracle comparison exists; it is not a passing screenshot.

## Ground truth acquisition

The existing diagnostic `frame ROW` path was checked first:
`main/runtime/debug_harness.cpp:419` calls `debug_frame_row`, implemented in
`display_facade.cpp:2173`. It packs `sprite.readPixel(...) != 0` into row-MSB
bits. This is a pre-panel nonzero threshold, **not the final SSD1306 Bayer
output**, and cannot certify the Contacts grey ticks. Existing host tests
cover domain policies rather than full OLED rasterization.

The new host capture compiles unmodified renderer headers and verbatim
extracted facade/helper functions. NVS is replaced only by a fixed language
read, `time()` by 2026-06-01 12:34:56 UTC, and surface/present/bus hooks by
offscreen equivalents. It uses an actual RGB332 LGFX Sprite and the actual
`Panel_SSD1306`/`Panel_HasBuffer` code. The software panel is rotated by 2,
matching the production configuration. It replaces display transport, not
font, geometry, rasterization, colour conversion or clipping. Output is
normalized back to logical coordinates and page-LSB order.

The actual dependency is LovyanGFX **1.2.25**, with complete source SHA256
recorded in [the manifest](../examples/mobus/reference/golden/manifest.json).
Installed-source hashes are authoritative; a different dependency must not
silently regenerate goldens. Host compiler: Apple Clang; SDL2 host functions
are linked without creating a window. The converter retains the original
char-selector's two uint32→uint16 colour-truncation warnings. Source is never
patched to silence them.

Font glyphs are captured independently from original arrays, with advance,
single-character measurement, actual fontHeight, ink and opaque masks, and
separate `drawString`/`print` origins. This is a reproducible font conversion,
not bitmap extraction from a finished Mo-Bus screenshot. Baseline offsets are
encoded relative to the original origin; no approximate substitute font is
used. Deduplication reduces 1302 glyph records to 296 unique masks.

## Inventory and source evidence

The exhaustive expression-level inventory is generated from the pinned
source: [coordinate/call inventory](mobus-source-coordinates.md),
[machine-readable inventory](mobus-source-inventory.json). It covers 46 facade
entrypoints, nine renderer/legacy files, all 22 screen source files and UI
model files. Constants, draw calls, font assignments, dynamic parameters,
delegates and screen callers are recorded verbatim with file/line numbers.
Coordinates below are logical pixels, not estimated from screenshots.

`L` below denotes `localized_ui_font`: Font2 for English, MisakiGothic8 for
Japanese. `C7` denotes MobusCustom7. `F2` denotes LovyanGFX Font2. A renderer
with no fixed header/footer is intentionally not given one.

| Screen/state family | Actual renderer and screen | Font / alignment / geometry | Selection / scroll / dynamics and dummy inputs | Coverage / difficulty |
|---|---|---|---|---|
| MENU | `menu_renderer.hpp`; `menu_screen.hpp/.cpp`, facade `render_menu_home` | C7; outer `(5,5,118,54)`; dividers y20/y42; centre `(41,20,40,23)`; Mode `(48,9)`; TUN/SET/TRA x15/53/93,y29; battery right edge46,y49; clock `(73,49)` | Brackets drawn before labels; notification circle `(37,25,r4)` black when first icon selected; radio bars x10/13/16,y52/50/48. Battery73%, radio3, 12:34:56. No scroll. | VERIFIED 4 / medium |
| CONTACTS / Contact Book | `contact_renderer.hpp`; `contact_book_screen.hpp` | F2; name rectangle `(30,2,68,18)`, centre text `(64,3)`; QSP `(32,22)`, CQ `(76,22)`; knob `(64,37,r7/r9)`; tuner x10..118,y54, ticks y50..58 | Triangle at selected slot, pending 5×5 box, unread circles; QSP/CQ indicator line; ten slots at `10+108*(i+1)/11`. Loading `(38,26)`. Fixed Hazuki/Taro, pending/unread/mode focus. No list harmonization. | VERIFIED 6 / high |
| Contact Action / pending / friend code | `contact_action_renderer.hpp` and facade; `contact_book_screen.hpp` action phase | Current pending/slot list uses `render_wifi_list`, not necessarily the older template; confirmation includes nickname, title/name/question y0/14/28, buttons y44; friend-code dividers y14/45 and selector y46 | Status, loading, request list, accept/reject, ten slots; fixed names/code needed. No live request. | UNVERIFIED / medium |
| Message Box / history | facade `render_message_box`; `message_box_screen.hpp` | Header F2 y0, divider y14, black line y15; body clip `(0,body_top,128,body_height)`; C7 ASCII y+2, Misaki8 other y+4; text x16, max width107 | Variable-height blocks; sender separator5px; outgoing highlights only 12px prefix; arrows; scrollbar x124 with 0x2104 track, min thumb6; notice box y53. Dummy sender groups, wrapped lines, offset, notices. | UNVERIFIED / high |
| OPEN CHAT room | `open_chat_renderer.hpp`; `open_chat_screen.hpp` | L; centred header `(64,0)`, divider y12; body y16..52,width128; row height `max(12,fontHeight+2)`; footer cursor `(0,56)` | Newest messages first for fitting; keeps first fitting lines per message; full inverse rows for mine; codepoint wrapping, not word wrapping. Fixed Hello/CQ, long English and Japanese. | VERIFIED 4 / high |
| Room Selector | same header; `open_chat_screen.hpp` | L; header y0, divider12; rows cursor `(4,16+12*i)`, inverse box y−2,height12; footer y56 | Selected row can overlap the next row's text due to F2 height16. LOBBY/OKINAWA/CQ, no cleanup. | VERIFIED 2 / medium |
| Open Chat compose | `make_open_chat_composer_render_api`; `open_chat_screen.hpp` | L; header0/divider12; wrapping message cursor `(0,16)`; Morse `(0,44)`, preview `(0,52)`, footer `(0,56)` | Fixed text, dots/dashes, preview; application owns draft. | UNVERIFIED / medium |
| Composer / step sequencer | facade `render_step_composer`; `composer_screen.hpp` | F2; BPM header `(2,0)`, divider12; 16 steps x4+7*i,y20,w5,h16; cursor frame7×20; playhead y15; summary centre y40; L footer y52 | Active step fill, cursor and playhead; fixed tempo120, PIANO, note60, cursor2, playhead4. | VERIFIED 2 / medium |
| SETTINGS | facade `render_setting_menu`; `setting_screen.hpp` | C7 ASCII fallback and L non-ASCII; four rows16px; labels `(2,6+16*i)`; status centre `(116,8+16*i)`; status text right edge126 | Full inverse selected row; On filled r3, Off erased r4+outline r3, Busy dots x111/116/121,r1; scroll first=max(0,selected−3). No header/footer. | VERIFIED 3 / medium |
| Confirm Dialog | `make_confirm_dialog_render_api`; shared widgets/settings dialogs | L; title centre `(64,10)`; rounded buttons `(12,34,40,18,r3)` and `(76,34,40,18,r3)`; text centres `(32,36)/(96,36)` | No/Yes inverse fill; no modal backdrop invented. Fixed Confirm?, selected0/1. | VERIFIED 2 / medium |
| Factory reset | facade `render_factory_reset_confirm`; `setting_screen.hpp` | L; title0, lines14/26; buttons y44, text46 | Different vertical layout from generic confirm is preserved. Fixed No/Yes. | VERIFIED 2 / medium |
| Language / confirmation | `setting_dialog_renderer.hpp`; `setting_screen.hpp`, factory setup | L per label; title English y1/Japanese y6; option base24+16*i; English text/highlight y−4,height16; Japanese text y, highlight y−2,height14; x8,w112 | Selected locale and confirmation. No typography standardization. | UNVERIFIED / medium |
| Sound settings / Boot sound | same dialog header; `setting_screen.hpp` | L; sound centres y6/18/30/42/52/60; boot centres y6/24/40/52 | Fixed enabled/volume/tone, selected tune/hints; bottom clipping must be preserved. | UNVERIFIED / medium |
| Firmware info / text modal / RTC / OTA-manifest / Mo-Bus info | same header and setting screen | Firmware F2 title0, left x2, hint54; text-modal F2 title4 and supplied line y; other dialogs dispatch through list/text-input/status | Fixed version/build/server strings, dates and selected field. Current source expressions retained in detailed inventory. | UNVERIFIED / medium |
| Wi-Fi scanning/connecting/error | facade `render_center_status`; `wifi_setup_screen.hpp`, factory setup | F2; centred lines y18/34 | Fixed Scanning..., Connecting..., Failed / retry. No radio scan. | VERIFIED 3 / low |
| Wi-Fi list / manual Other | facade `render_wifi_list`; Wi-Fi/factory/contact actions | F2 English, localized with C7 fallback otherwise; four rows16px; cursor x10,y16*i; localized text y+4; **title parameter is unused** | Inverse row; scroll selected−3; SSID omission when length≥12 uses first6 bytes + ... + last3 bytes. Fixed five rows including Other. | VERIFIED 3 / medium |
| Password / SSID / generic Text Input | facade `render_wifi_text_input`, `render_text_input`; Wi-Fi/factory/settings | F2; title cursor0,0; dividers14/45; value cursor0,15; character strip y46, spacing8; delete polygon tip(114,52), body x118..127,y45..60 | Secret value replaced by one `*` per **byte**, not per codepoint; selected glyph inverse; delete fg/bg uint16 truncation retained. Fixed secret→six stars. | VERIFIED password/delete 2; other states UNVERIFIED / medium |
| CQ Chat / Realtime Talk | facade `render_realtime_scan`, `render_realtime_talk`, `render_talk_input`; respective screen headers | Peer list F2 rows16,x10; connecting centres18/34; incoming title0/name18/status31, buttons44/46; conversation split y32, remote y35; talk frame `(3,3,122,58)`, content `(7,7)`, width114 | Cursor blink, language overlay `(52,24,24,18,r2)`, scrolling text tail, inverse transition; scan dots phase350ms and fixed alignment. Dummy peers, message and time required. | UNVERIFIED / high |
| Ehagaki menu | facade `render_ehagaki_menu`; `ehagaki_screen.hpp` | L title centre y0; C7 POST/MY POST/TIMELINE y16/32/48; highlight `(9,y−1,110,15,r2)` | Fixed selected0/2; no network. | VERIFIED 2 / medium |
| Ehagaki viewer / timeline / post/public confirm | facade viewer/confirm functions; Ehagaki screen | Frame `(2,2,124,60)`; application bitmap122×58 at `(3,3)`; back text x5,width116, line9, title2/body3 rows; C7 ASCII / lgfxJapanGothic_8 others | Page, text scroll/reveal, flip inset, page arrows and sync notices; fixed bitmap/text/times required. Post/public dialogs differ from generic confirm. | UNVERIFIED / high |
| Ehagaki text edit | facade `render_ehagaki_text_input`; Ehagaki screen | English header2/divider14/body16; Japanese header5/divider17/body19; count C7, header gap4; body126px wide, three14px lines | Mixed glyph styles, cursor, language overlay and character count. | UNVERIFIED / high |
| Draw / Ehagaki canvas | facade canvas/side-menu functions; draw/Ehagaki screens | Draw packed row-LSB128×64; Ehagaki packed contiguous row-MSB122×58 plus frame/offset3; sidebars x0..16/x111..127; optional stroke popup `(96,8,14,40)` | Application-owned dummy bitmap; inverted cursor (cross for Draw, point for Ehagaki), anchor line/rect, tools, undo/redo, stroke1..3, overlay `(34,21,60,22,r3)`. Draw canvas Bresenham uses inclusive comparisons distinct from drawLine. | UNVERIFIED / high |
| Synth | facade `render_synth_sequencer`; `synth_screen.hpp` | C7; six track masks and step grid, page/active-note/tempo/status/save dialog; all draw expressions in coordinate inventory | Fixed track masks, playhead, sample/error/loading, dialog mode, save slot; no audio worker. | UNVERIFIED / high |
| TRA | facade `render_tra_launcher`; screen dispatch in app shell | C7; 3×2 boxes39×25 at x2+42*col,y5+29*row; text centred y+3/+13 or y+8 | Fixed selected0/3; inverse boxes; split Local/CQ, Eha/gaki, Mopp/ing, Maji/mun retained. | VERIFIED 2 / medium |
| Profile | facade `render_profile_info`; `profile_info_screen.hpp` | F2; labels x0,yoffset+28*i; values y+14; no header/footer | Vertical offset; empty→(none), values>24 bytes truncate +...; Name/ID/Version. | VERIFIED 2 / low |
| Factory setup / Morse hello | `render_setup_morse_hello`, language/Wi-Fi/status/input; factory setup | F2 centred18/34; Morse dot60ms, intra40ms, letter120ms, word360ms; fixed dash argument; staged UI | Fixed started/now, CQ CQ / DE Mimoc K, locale, AP/SSID/password and completion/error. No NVS/network. | UNVERIFIED / high |
| Text / centred status / blank | facade status/blank; `text_screen.hpp` and callers | L; single line centre26, two lines18/34; blank all off | Fixed Mo-Bus/Ready. | VERIFIED 3 / low |
| Offline / Error notice | facade `render_offline_notice`/`render_error_notice` | Icon `(52,6,24,30)`, label L/F2 centre y43 | **87-byte icon, 90-byte request**; safe port draws defined29 rows, unknown row clear. No golden from undefined memory. | SOURCE-FAITHFUL 2 / reference uncertainty |
| Watch / lock / boot logo | legacy `oled_view.hpp`; `show_watch_display` and menu/factory paths | F2/Font4; time-unavailable bitmap; Mimoc logo `(32,0,64,64)`; exact watch expressions in inventory | Fixed RTC validity/time/battery/notification, page selection. Requires additional assets and legacy surface-state capture. | UNVERIFIED / high |
| Game trainer / clear / Typing Word / result | facade game functions; `game_screen.hpp/.cpp` | F2, FreeMono12pt7b, Font0, FreeMono9pt7b; title/input/result geometries differ | Fixed target/morse/scores/streak/time, cursor and result; elapsed formatting can be done outside Core. | UNVERIFIED / high |
| Arcade | facade `render_arcade`; `arcade_screen.hpp/.cpp` | C7 status plus game-owned pixel scene | Fixed game seed/frame/best/overlay/canvas and now; no game runtime in UI Core. | UNVERIFIED / high |
| Low battery / charging standby | facade low-battery functions; app-shell maintenance | L with battery/charging bitmap/status; exact functions listed in inventory | Fixed battery/resume mV and charge state; timers must be fixed. | UNVERIFIED / medium |
| OTA progress / update status | `display_render_ota_progress` and settings update path | L title2/status18; progress frame `(10,36,108,12)`; fill `(11,37,106*percent/100,10)`; F2 percent centre50 | Fixed phase and percent; direct LCD path, not Sprite. No actual updater. | UNVERIFIED / medium |

The older `setting_renderer.hpp` and contact-pending/confirm templates are
inventoried but not automatically treated as current screen implementations.
The current facade and actual screen call sites take precedence.

## Font inventory

| Font | Actual use / data | Reproduction |
|---|---|---|
| MobusCustom7 | Menu, Settings ASCII, Message Box ASCII, TRA, Synth, canvas menu; `font_mobus_custom7.cpp` | Original bitmap/advance/opaque origin converted; actual fontHeight7. Printable ASCII and original fallback. |
| Font2 | English localized UI, Contacts, Profile, Wi-Fi, various headers; LovyanGFX `Fonts/Font16.h` | Original bitmap/metrics; height16; variable advances (e.g. space6, H8). |
| MisakiGothic8 | Japanese localized UI and chat/history | Original current `$30A0-$30FF` subset; actual fontHeight7, Katakana typically advance8. Missing hiragana/kanji and ASCII retain the original 7px fallback raster. |
| U8g2B12Japanese1 / lgfxJapanGothic_12 | Talk input: Katakana uses B12 when present, other Japanese-block glyphs use JapanGothic12; non-Japanese blocks retain Font2 | Active via `select_chat_glyph_style` in legacy prelude; not yet converted. |
| lgfxJapanGothic_8 | User-authored Ehagaki back text | Inventoried, not converted; more glyph coverage than Misaki subset. |
| Font4 | Legacy watch/large text; facade menu setter is overridden by C7 before drawing | Not yet converted. |
| Font0 / FreeMono9pt7b / FreeMono12pt7b | Typing Word and trainer/results | Not yet converted. |
| MisakiGothic16 / HeadUpDaisy14x8,14x16 / lgfxJapanGothic_16 | IME selection helper in legacy prelude chooses by base-font height and glyph coverage | No direct current facade use of that selector found; inventory keeps this available path separate from active Talk styling. |
| MobusCustom14 / UnifontJapanese1 |  Assets exist in pinned display component | No active direct font assignment found in the inspected current facade/renderer paths. Presence does not imply use; retain inventory without enlarging Core. |

Notices, source hashes and author provenance are in
[reference/provenance.md](../examples/mobus/reference/provenance.md).
There is no Japanese font table in `src/font.zig`.

## Primitive and 1-bit semantics

Pixel, H/V lines, rect, fillRect, arbitrary line, circle/fillCircle,
triangle/fillTriangle, roundRect/fillRoundRect, bitmap, text, centred text,
inverse text and clipping occur in current renderers. H/V widths are counts;
rectangle right/bottom edges are x+w−1/y+h−1. Existing Mono1 behavior remains
unchanged. `mimoc_ui.raster_compat` adds opt-in integer Lovyan-compatible line,
triangle, circle, filled circle and rounded rectangle policies. No Mo-Bus
widget or colour type is added to Core.

Contacts uses 0xC618 as an **int RGB565 colour**, quantized through RGB332.
Read-back RGB565 is 0xDEDF, expanded RGB=(222,219,255). The original integer
gamma formula `(r²*19749+g²*38771+b²*7530)>>24` gives 198. OLED pixels use
`gray+Bayer[physical-phase] >= 256`; logical phase is rotated by2. These ticks
are neither uniformly on nor discarded. OPEN CHAT uses unsigned 0xFFFFu for
inverse text background: RGB888 cyan, gamma179; its row fill still uses int
0xFFFF and becomes white. Reference retains this seemingly inconsistent tint
as a 1-bit dither pattern. Original colours were not normalized.

All 42 verified frame comparisons cover original coordinates, text centring
rounding, foreground/background, primitive edges, clipping, original width
wrapping and overlaps. The generic Core word-boundary wrapper is **not**
substituted for the original Open Chat codepoint-only wrapper. Separate font
provider tests validate UTF-8-safe wrapping for Hello world, こんにちは,
沖縄県東村, CQやりませんか？ and Hello 沖縄 CQ.

## Commands and frozen-baseline policy

```sh
zig build mobus-reference-snapshot -- --list
zig build mobus-reference-snapshot -- menu/default --raw > menu.raw
zig build mobus-reference-snapshot -- chat/japanese --pbm > chat.pbm
zig build mobus-reference-diff -- --screen contacts/unread \
  --expected examples/mobus/reference/golden/contacts-unread.raw
zig build check-mobus-reference
zig build check-mobus-reference-c
zig build studio
```

Diff reports matching/different pixels, first x/y, first framebuffer byte and
mismatched-byte count. It writes expected/actual/XOR PBM and raw buffers under
`zig-out/mobus-diff` and exits unsuccessfully for any mismatched pixel. Raw
format is exactly 1024 bytes, index `(y/8)*128+x`, bit `y%8`; PBM is P4 row-MSB.

```sh
python3 tools/capture_mobus_reference.py \
  --repo /path/to/Mobus_ESP_IDF --lgfx /path/to/existing/LovyanGFX \
  --output /tmp/new-empty-staging-directory --verify
python3 tools/mobus_reference_inventory.py \
  --repo /path/to/Mobus_ESP_IDF --output /tmp/inventory
```

The capture script requires the pinned commit locally, existing Apple Clang
and SDL2 at `/opt/homebrew`; it downloads nothing. It rejects a nonempty output
directory. `--verify` compares source/dependency/harness hashes, converted
assets and independent buffers against the frozen baseline. New baseline
acceptance requires reviewing source/input changes; a failed equality test is
never repaired by rendering Zig into `golden/`.

## Studio and Candidate boundary

Choose **UI LAB** or press **L**. Next Screen and Next Scenario buttons select
fixed states; Up/Down move within that screen's scenarios. Left/Right/Enter
cycle Legacy, Candidate, 500ms 50% alternate, XOR and side-by-side. The
inspector reports differing pixels and VERIFIED/SOURCE-FAITHFUL status.
Hover reports logical x/y and both on/off bits. Single-preview4× logical
scaling uses the existing Studio2× window scale (8× on screen); side-by-side
uses2× logical scaling. Presentation scaling never changes 128×64 buffers.

`examples/mobus/reference/` owns immutable geometry and converted legacy
assets. `examples/mobus/design/` is an independent entrypoint, initially seeded
by the reference; it performs no redesign. Both receive the same Scenario and
application-owned Fixture. The existing `examples/mobus/main.zig` demo remains
separate and available. The inspector does not mutate either renderer.

## Portability and remaining blockers

Validation on 2026-10-10: `zig build test`, `zig build test
-Doptimize=small`, `zig build check-embedded`, `zig build
check-c-backend-host`, `zig build check-mobus-reference-c`, and the default
simulator/Studio/desktop build all pass. The existing comparison retains
2,060 × 1,024 equal bytes; the new reference comparison covers 44 frames.
The standalone reference C compilation reports 34 warnings, retained in
`compiler.log`; its undefined symbols are only bzero, memcpy and memset.
Independent capture regeneration with `--verify` reproduces every frozen
input, converted asset and all 42 defined ground-truth frames. The diff CLI
passes the original Contacts fixture and rejects a deliberately flipped
single pixel at (0,0), byte0. Studio side-by-side output was visually checked.

The renderer uses fixed-capacity integer buffers, application-owned output,
borrowed glyph masks and the existing font Provider; it needs no allocator,
libc, OS, float or macOS font service. `check-mobus-reference-c` lowers the
**same** reference Zig code with upstream0.17.0, compiles with host Clang, and
compares all44 native/C frames (including the two explicitly source-faithful
programs). Its standalone object audit permits only memcpy/memset/memmove/
bzero. Host stack runtime instrumentation is disabled for that standalone
library check with `-ffreestanding -fno-stack-protector`; ABI assertions and
generated C remain untouched. This task does not compile/link ESP32 firmware.

Remaining screen families are catalogued with exact source evidence but still
need fixed view-model fixtures, original-font conversion and original-renderer
capture adapters. Message Box uses PSRAM-backed application types; legacy
watch, user-authored Ehagaki, games and Synth need further source-specific
adapters/assets. This is local capture/font/raster coverage work, not evidence
of a structural mimoc-ui limitation. Font4/GFX datum metrics and application
bitmap formats must be verified before marking those screens pixel-perfect.

Offline/Error's last icon row cannot be truthfully certified from its current
source because of the out-of-bounds read. A physical capture could document
one device build's pixels but would not make that behavior defined. No
production Mo-Bus fix is made here. Physical capture and inherited persistent
Sprite-state transitions remain outside the verified fixed-initial-state scope.

The evidence supports reproducing the current UI and keeping a frozen Legacy
beside a Candidate in Studio. It does **not** yet certify every current screen.
The shared renderer can follow the existing ESP32-S3 C-backend path; this work
proves host C equivalence, while target compilation/integration remains the
separate portability workflow already present in the repository.
