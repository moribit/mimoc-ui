# Desktop Foundation (Zig 0.17.0)

Desktop Foundation adds bounded input routing and platform fonts to the existing declarative, application-owned Mono1 model. It introduces no networking, threads, task system or allocator in Core. The implementation starts from main `b41759e`.

## Enable Desktop capabilities

```zig
const Display = mimoc.runtime.Runtime(mimoc.profiles.desktop);
const Ui = mimoc.ui.Ui(Id, mimoc.profiles.desktop);
var display = Display{};
display.viewport = .{ .w = 480, .h = 270 };
```

`desktop_input = true` enables capture, pointer press tracking and an optional FontProvider in a custom configuration. Capacities and viewport remain independent. Existing configurations omit this field, retain their RAM sizes and continue using `display.action(.down)` / `display.action(.activate)`. Desktop `action` also retains navigation behavior; while captured it returns null. Use `dispatch(.{ .action = ... })` to deliver editing actions.

## Input → application intent

`input.InputEvent` distinguishes Action, borrowed UTF-8 text, physical key down/up, logical pointer down/up/move and scroll. Keys include enter, escape, tab, backspace, delete, space, arrows, home, end and unknown. Text is a separate event; consume or copy it before the platform callback returns. There is no event queue owned by Core.

`display.dispatch(event)` returns the unchanged event, a stable target ID, `interaction`, `activated`, and `previous_focus`. The application can compare `previous_focus` with `display.focused_id` to observe focus changes, including pointer clicks and navigation. Rebuilds remove focus/capture when the target disappears or becomes disabled.

- Navigation arrows/Tab move focus, Enter activates.
- `captureFocus(id)` and `releaseFocus()` are generic APIs for any enabled focusable widget. Captured arrows stay with that widget.
- Activating a TextField captures it. Enter/escape (or captured activate/back Actions) releases capture and returns `blur`; the original event still identifies submit versus cancel. Cancel exits editing; it does not roll back application text.
- A Button activates on pointer down inside followed by up inside. Release outside cancels activation. Clipped/disabled targets cannot be activated. Space down/up also presses/releases the focused Button.
- A pressable returns `pressed` and `released`; `activated` additionally identifies release inside. Applications needing Morse key lifecycle can consume raw Space down/up or pointer events. Repeated physical down is ignored by the demo for CQ; text key repeats still insert text.
- A scroll event targets the innermost ScrollView under its logical pointer position. The application clamps and changes its own offset, then rebuilds. The offset is never owned by Runtime.

Window focus loss is delivered by the Desktop bridge, and the demo clears its CQ pressed state and releases capture. `display.cancelInput()` also clears Runtime press tracking; applications must clear their own held-input state on window focus loss.

## TextField and application-owned UTF-8 editing

```zig
var buffer: [256]u8 = undefined;
var len: usize = 0;
var cursor: usize = 0;
var field = mimoc.text_edit.Field{ .placeholder = "Message..." };

// Before each rebuild; field, buffer and text slices outlive rendering.
field.text = buffer[0..len];
field.cursor = cursor;
ui.textField(.message, &field, .{ .size = .{ .w = 240, .h = 22 } });

// While the field is captured, use the returned event/target.
if (mimoc.text_edit.intent(result.event)) |edit| {
    switch (edit) {
        .submit => sendFromApplicationState(),
        .cancel => {},
        else => try mimoc.text_edit.apply(&buffer, &len, &cursor, edit),
    }
}
```

The descriptor is borrowed, just like text/bitmap slices. Keep it in application state, not a temporary helper's stack frame. `Node.text` stores the descriptor bytes for the `text_field` kind; ordinary text kinds continue storing UTF-8. This reuses the existing borrowed payload slot and avoids per-node RAM growth. Renderers interpret it only for that kind. Do not pass descriptor bytes to text-layout functions.

The bounded helper supports insertion, backspace, delete, left/right, home/end, submit and cancel. Cursor is a byte offset that is always normalized to a decoded codepoint boundary. `Hello沖縄` moves left by the whole `縄`. Insertions validate UTF-8 and check capacity before changing memory. Errors leave input state unchanged. It handles codepoints, not extended grapheme clusters, selections, clipboard or undo.

`password = true` draws one ASCII `*` per codepoint, including correct cursor advance, without copying or retaining password text. Empty fields show the placeholder. `disabled = true` on Field or common widget Options prevents focus/input. Button/pressable Options also use `disabled`; applications express loading with a label plus disabled state. TextField horizontally follows its application-owned cursor. Enter submits a single-line field. TextArea is deferred.

## FontProvider boundary

```text
Core layout / wrapping / Mono1 renderer
                 │
       font.Provider callbacks
          ┌──────┴──────┐
     bitmap default   macOS adapter
       no libc        CoreText / CoreGraphics
```

`font.Provider` borrows an optional opaque context and supplies Unicode `advance_fn`, `raster_fn`, and `line_height`. `measureText` sums the same advances used for drawing and wrapping. A raster callback writes a caller-provided 128-byte row-MSB mask (32×32, top-left origin); it must clear unused pixels. Advance and line height should fit this bounded cell. The provider/context outlives its Runtime; no mask is retained by Core.

`display.setFontProvider(provider)` relayouts the view. `font.measureWith`, `layout.measureWith`, `wrap.heightWith`, `wrap.drawWith` and `wrap.ProviderIterator` support provider-based measurement. Their provider argument is optional (pass `null` for bitmap). Existing APIs and bitmap Font enum remain compatible. Non-Desktop Runtime calls specialize to the bitmap path at compile time.

The macOS adapter is entirely in `src/platform/macos/font.zig` and `font.m`, and linked only by the Desktop build target. Core never imports it. CoreText chooses a fallback font for each scalar, lays out that scalar with CTLine, then CoreGraphics renders a bounded grayscale scratch cell with font antialiasing/smoothing disabled. Threshold 128 converts it to Mono1. The adapter releases all per-call platform objects. ASCII and Japanese metrics are supplied by the same layout. Font rendering is codepoint-based; complex shaping across scalars, color emoji, bidirectional layout and advanced Unicode line breaking are outside this foundation.

The existing bitmap `wrap.Iterator` retains its original footprint; `ProviderIterator` carries the optional provider for Desktop layout. Both iterators preserve UTF-8 boundaries, explicit newlines and ASCII word breaks; oversized single glyphs are emitted intact so iteration always progresses. Variable-height list applications should derive each item height with `wrap.heightWith` and the same provider/width/line height used by the view.

Relevant Apple interfaces: [CTFontCreateForString](https://developer.apple.com/documentation/coretext/ctfontcreateforstring(_:_:_:)), [Core Text](https://developer.apple.com/documentation/CoreText).

## macOS window modes

`src/platform/macos/window.zig` provides typed `Event { input, resize, focus_lost, tick }`, `run`, `present` and `viewport` over the C bridge. It is an optional application/platform import; Core does not import it.

`mimoc_window_run` retains fixed-size integer-scale Simulator/Studio behavior and their legacy key/click callbacks. `mimoc_desktop_run` enables resize and distinct physical/text/pointer/scroll callbacks. The bridge exposes `mimoc_window_present` and `mimoc_window_viewport`. Resize calls the application's callback; the application selects its bounded framebuffer dimensions, rebuilds and presents. No framebuffer is allocated by the bridge.

Logical coordinates are AppKit points divided by scale; backing pixel density is deliberately excluded. Raster output scales by the same factor, so Retina pointer positions match Mono1 pixels. The demo bounds its framebuffer to 1024×768; this is an application capacity, not a framework viewport restriction. macOS minimum content size is 128×64 logical pixels. Simulator remains 128×64 with integer scaling.

The NSTextInputClient bridge retains marked text only in the platform layer and emits committed UTF-8. Candidate-window positioning currently uses a fixed location near the input row; marked-text decoration and exact caret placement are future platform refinements.

## Mock demo and validation

Run `zig build desktop-demo`. The initial viewport is 480×270. The mock shows Contacts, Unicode chat, an application-owned input, disabled empty SEND, wheel scroll, and CQ KEY. Space or mouse hold indicates KEY DOWN; release indicates KEY UP. Enter in the captured field submits to mock history. No network connections are made.

`zig build check-desktop` compiles the demo without a window. `MIMOC_DESKTOP_SNAPSHOT=/tmp/desktop.pbm zig build desktop-demo` produces a headless Mono1 screenshot using the real macOS font adapter. `zig build test` includes native font masks and mock input/resize tests on macOS, alongside portable tests for editing, capture, password, disabled widgets, measurement, wrapping and 128×64 / 320×180 / 480×270 / 640×360 viewports.

Application events from a future network worker remain outside Core: drain the application's queue, update application state, rebuild. UI dispatch returns intent; it does not schedule work.

## Footprint and boundary review

The same Zig 0.17.0 compiler/target/optimization was used before and after, with the original source extracted from `b41759e`. CoreText, AppKit, the native input bridge and TextField rendering are excluded from the freestanding bitmap path. The new per-node disabled flag uses existing struct padding; Desktop input/capture/provider storage is a compile-time conditional field. No allocator is required by Core.

| ABI/type | Before | After | Delta |
| --- | ---: | ---: | ---: |
| macOS Node | 48 | 48 | 0 |
| macOS Runtime(8,1) | 528 | 528 | 0 |
| macOS Runtime(16,4) | 1096 | 1096 | 0 |
| RV32 Node | 40 | 40 | 0 |
| RV32 Runtime(8,1) | 460 | 460 | 0 |
| RV32 Runtime(16,4) | 968 | 968 | 0 |
| RV32 Runtime(32,4) | 1768 | 1768 | 0 |
| RV32 in-place Builder(16) | 40 | 40 | 0 |
| RV32 high-level Ui embedded | 52 | 52 | 0 |

A linked freestanding probe from `src/ui_embedded_smoke.zig`, using `zig build-exe ... -target riscv32-freestanding -O small -fentry=mimoc_ui_page` and `llvm-size`, reports text/readonly/unwind aggregate **12,301 → 12,387 bytes (+86, about 0.7%)**, data=0 and bss=0 in both. This is a comparison probe, not a board firmware Flash measurement; drivers, linker script and real application globals are absent. Runtime is local stack storage in this probe, so data/bss=0 does not mean it uses no RAM. Exported `footprint_embedded` type-size arrays match byte-for-byte. The small code delta covers generic disabled/focus/kind handling and bounded wrapping arithmetic. No native font tables or platform callbacks are linked. Earlier review documents contain older compiler ABI sizes; the table above is the current Zig 0.17.0 result.

Final validation: Debug and ReleaseSmall each pass all 57 tests (including two native Desktop tests on macOS); `check-embedded`, `resource-report`, and installation builds pass. Simulator, Studio and Desktop window run steps started without runtime errors and were stopped after the smoke check. The computer-use tool could not select these standalone executables, so interactive mouse/resize automation was not completed; callback tests and the visually inspected native-font PBM provide the recorded input/resize/render validation. Manual Retina/IME candidate UI checks remain useful before shipping a product.
