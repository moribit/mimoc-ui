# Mo-Bus UI reference implementation review

## Scope and source

The reference is `moribit/Mobus_ESP_IDF` at `fix/after-release`: ContactBook/Contact Renderer, MessageBox, OpenChat/Composer, Ehagaki Canvas, and ScreenIntent. The Studio demo reproduces their interaction model with mock data. It does not link ESP-IDF, LovyanGFX, network services, or Mo-Bus firmware code.

## Generic Mimoc UI features

| Feature | API | Storage and behavior |
| --- | --- | --- |
| Variable height list | `scroll.variableTotalHeight`, `scroll.variableVisibleRange` | Scans application-owned `[]const u16` heights; returns clamped offset, visible indices, first content coordinate, total height. Only visible and nearby Chat items are built. |
| Wrapped bitmap text | `widgets.wrappedText`, `wrap.Iterator`, `wrap.lineCount`, `wrap.height` | UTF-8 codepoint boundaries, explicit newlines, word breaks with codepoint fallback. Measurement and drawing use the same iterator and current font advance. Unsupported glyphs draw `?` once per codepoint. |
| Scrollbar | `scroll.scrollbar`, `widgets.scrollbar` | Integer thumb geometry from viewport/content/offset. A composite track and thumb; no owned scroll state. |
| Bitmap layer | `widgets.Bitmap`, `widgets.bitmap`, `Renderer.bitmapFormat` | Application-owned one-bit slice; row-MSB and SSD1306 page-LSB formats, explicit stride, clipping, 122×58 images. |
| Tuner | `widgets.Marker`, `widgets.tuner`, `widgets.tunerTick` | Generic slot rail, empty/pending/unread markers, animated selected triangle. Marker slice remains application-owned. |
| Knob | `widgets.Knob`, `widgets.knob`, `widgets.knobPoint` | Integer 2–5 step selector, focus ring, animated indicator endpoint. No runtime sine/cosine or floating point. |

The new draw primitives use existing `Node.text`, `min_size`, `padding`, `spacing`, and `offset` fields. `Node` did not gain fields. Tuner/Knob indicators use stable IDs and the existing presentation tracks; `Runtime.update(now_ms)` alone advances them. Rendering is read-only. Both controls work with animation disabled, including `Runtime` with zero animation capacity.

## Mo-Bus component and screen boundary

Generic widgets live in `src/`; Mo-Bus presentation lives in `examples/mobus/`. `components.zig` has `screenHeader`, `contactTuner`, `modeSelector`, `chatMessage`, `morseComposer`, and `canvasToolbar`. `screens.zig` composes HOME, CONTACTS, CHAT, COMPOSER, EHAGAKI. `main.zig` owns mock navigation, contact/mode selection, Chat scroll, composer state, and the application bitmap. No Contact or Morse data model enters Core.

- **CONTACTS:** 10 slots, including normal, empty, pending and unread markers. Focus switches between tuner and knob with Up/Down; Left/Right selects a slot or QSP/CQ; Activate opens Chat. The title border, focused knob, and horizontal scale follow the firmware's radio design.
- **CHAT:** 12 mixed-length messages use wrapped text and calculated per-item heights. The visible range is built with one viewport of overscan so an eight-pixel scroll step can animate through adjacent items. Incoming/outgoing markers, clipping, and the right scrollbar are composed from generic primitives.
- **COMPOSER:** Header, wrapped body, mock Morse sequence, decoded preview, and send hint. Activate changes mock text; no decoder is included.
- **EHAGAKI:** An application-owned 122×58 row-MSB bitmap under a cursor, line/rectangle preview, toolbar, and optional status panel. Arrow actions move the cursor; Activate cycles tools and toggles the panel. There is no upload, autosave, or undo system.

The fixed-capacity `Navigation(Screen, 5)` retains focus and Chat offset in each entry. Back traverses COMPOSER → CHAT → CONTACTS → HOME and restores contact focus, selected contact, mode, and Chat scroll. Push/pop use the existing single-view slide transition. Studio's Preview Runtime remains 128×64 Mono1; Studio chrome has a separate 704×336 Runtime/surface and nearest-neighbor composition. Studio's existing Classic, Widgets, and Navigation demos remain selectable, followed by MO-BUS. `mimoc-studio-snapshot contacts|chat|composer|ehagaki` writes the complete Studio PBM for inspection.

## Memory

Measured with `src/footprint.zig` on macOS and `src/footprint_embedded.zig` compiled for `riscv32-freestanding -O ReleaseSmall`:

| Type | macOS bytes | RV32 bytes |
| --- | ---: | ---: |
| Node | 48 (unchanged) | 40 (unchanged) |
| Runtime(16,4) | 936 (unchanged) | 804 |
| Runtime(32,4) | 1704 (unchanged) | 1444 |
| Studio Runtime(64,8) | 3384 | — |
| InPlaceBuilder(16) | 48 | 40 |
| Animation Track | 36 | 36 |
| Navigation(Screen,5) | 42 | 42 |
| ScrollState | 2 | 2 |
| VariableRange temporary value | 32 | 20 |
| Scrollbar geometry temporary value | 6 | 6 |
| Tuner API options temporary value | 24 | 16 |
| Knob API options temporary value | 8 | 8 |
| Transition | 24 | 24 |

The representative CH32V003 configuration is Runtime(16,4) 804 + in-place builder 40 + Navigation(5) 42 + ScrollState 2 + Transition 24 + page buffer 128 + ten marker bytes and two selection bytes = **1052 bytes**, leaving **996 bytes** of 2 KB before driver globals, application data, and stack. Tracks are already inside Runtime; they are not counted twice. The 928-byte Ehagaki mock canvas belongs to the Desktop demo and is not a viable additional RAM allocation on this CH32 configuration. Embedded applications must keep large bitmaps in ROM or platform storage, or use smaller assets. The 64-node Studio Preview capacity is a Desktop choice, not a CH32 requirement.

## Validation and limits

`zig build test` covers mixed heights, partial/oversized/empty lists, wrapping pixel boundaries/newlines/UTF-8, scrollbar positions and huge content, bitmap stride/format/clipping/page boundary, animated tuner/knob end positions at 10–60 FPS, full framebuffer versus eight pages while animating, and HOME/CONTACTS/CHAT/COMPOSER/EHAGAKI navigation. `zig build-obj src/widget_embedded_smoke.zig -target riscv32-freestanding -O ReleaseSmall` compiles the new widgets in a no-allocator page-render path. The Core still uses std only, no libc, no heap, and no floating point.

The reference font provides ASCII glyphs and a one-cell fallback for other UTF-8 codepoints. Japanese glyph shapes and variable-width font providers remain future work, though the wrap iterator passes decoded codepoints to font metrics. `ScrollState.offset` is i16; applications with content taller than its representable scroll range need a wider application-owned offset and an adapter for the view. The Chat demo culls distant items; a large jump beyond its overscan range can leave an animated intermediate frame sparse. The small-device transition capability uses one view; it does not keep two screen trees or framebuffers.

Future ESP32-S3 integration should provide only clock, Action mapping, and Mono1 bitmap delivery through an application adapter. The Core and demo do not introduce an ESP-IDF or LovyanGFX boundary.
