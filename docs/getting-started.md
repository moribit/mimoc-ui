# Getting started

Mimoc UI builds a view in fixed storage, updates presentation from an external clock, and renders the same view to a full Mono1 framebuffer or an SSD1306 page. The application owns its state.

```zig
const mimoc = @import("mimoc_ui");
const Id = enum(u16) { home, title, line, chat, cq, ehagaki };
const Display = mimoc.runtime.Runtime(mimoc.profiles.tiny);
const Ui = mimoc.ui.Ui(Id, mimoc.profiles.tiny);

fn homeScreen(ui: *Ui) void {
    var screen = ui.column(.home, .{ .padding = 2, .spacing = 1 });
    defer screen.end();
    ui.text(.title, "MO-BUS");
    ui.divider(.line, 120);
    ui.button(.chat, "CHAT");
    ui.button(.cq, "CQ");
    ui.button(.ehagaki, "EHAGAKI");
}

fn rebuild(display: *Display) void {
    var ui = Ui.begin(display);
    homeScreen(&ui);
    ui.finish(); // Debug panic or ReleaseSmall trap on a programming/configuration error
}
```

Create a `Display` once, call `display.update(now_ms)` with your platform's monotonic millisecond clock, and call `rebuild(&display)` when application state changes. For input, `_ = display.action(.down)` moves focus. `display.action(.activate)` returns a focused `u16` ID; compare it with `Ui.childId(Ui.rootId(.home), .chat)` to update application state. Rebuild after changing that state. The Core neither polls keys nor owns application booleans.

For a full 128×64 Mono1 image, use `var pixels: [1024]u8 = undefined; try mimoc.headless.render(display, &pixels, 128, 64);`. For SSD1306 pages, call `display.update(now_ms)` once per frame, then render pages 0–7 independently with `mimoc.headless.renderPage(display, &page, 128, page_index)`. Do not update between pages.

`Ui` methods accept a typed application ID. Container guards close with `defer`; composite internals receive stable IDs from the framework. If a screen needs a low-level primitive, `ui.primitive(...)` is available. `runtime.beginView()` and `view.add(...)` remain supported; `src/widget_embedded_smoke.zig` is the low-level reference.

Set capacities explicitly with `Runtime(.{ .max_nodes = 16, .max_animations = 4 })` or use `profiles.tiny`, `profiles.embedded`, or `profiles.desktop`. `display.resources()` reports used/max nodes and animation tracks. For error handling without a panic, call `ui.finishChecked()` and inspect `ui.diagnostic()` in diagnostic builds.

Desktop input, Unicode fonts, text editing and resize are described in [Desktop Foundation](desktop-foundation.md). Run `zig build desktop-demo` for the mock application.
