# Mimoc UI

Small Zig UI core for monochrome embedded displays. The implementation includes fixed-capacity declarative nodes, integer layout, action/focus navigation, SSD1306-format software rendering, headless snapshots, a macOS virtual display, time-based animation, and Mimoc UI Studio.

```sh
zig build test
zig build run
zig build studio
zig build resource-report
```

The simulator uses arrow keys or WASD to move focus, Return/Space to activate, Escape to go back, and mouse clicks to select controls. Press M to cycle through the classic, Widgets, and Navigation demos. Its display is a 128×64, 1-bit page-order framebuffer scaled 8× with nearest-neighbor pixels.

`src/root.zig` has no libc or third-party dependencies. `src/platform/macos/window.m` is the isolated AppKit window bridge. Rendering the same settled UI one page at a time uses `headless.renderPage` with a 128-byte buffer.

For application screens, use typed IDs with `ui.Ui(Id, config)`, scoped containers, and ordinary Zig component functions. [Getting started](docs/getting-started.md), [components](docs/components.md), and the [embedded guide](docs/embedded-guide.md) show the recommended API and page-render path. The low-level `runtime.beginView()` / `finishView()` API remains available. `src/ui_embedded_smoke.zig` compiles the high-level path for RV32 freestanding; `src/widget_embedded_smoke.zig` remains a low-level reference. The [API stabilization review](docs/api-stabilization-review.md) records RAM growth, validation, and current limits.

Use `Runtime(.{ .max_nodes = 16, .max_animations = 4 })` and set a node's `.animation` to a compact `Animation` value. Call `runtime.update(now_ms)` once per frame, then render the full framebuffer or each page without changing the time. The [Milestone 5 review](docs/milestone-5-review.md) records measured sizes and verification.

[Studio](docs/milestone-6-review.md) uses Mimoc UI for its own controls and a separate preview Runtime. Its FPS setting changes the update cadence; Pause and Step use a manual clock.

Studio's [viewport and composition review](docs/studio-layout-fix.md) describes its 704×336 Studio surface, separate 128×64 Preview framebuffer, integer pixel scaling, and headless PBM snapshot command.

The [Widget and Navigation review](docs/widget-navigation-review.md) describes Checkbox, Toggle, Progress, Icon, Panel, Clip, ScrollView, List, fixed-capacity Navigation, and screen transitions. Studio's DEMO control cycles through Classic, Widgets, Navigation, and MO-BUS. The simulator retains its first three demos.

The [Mo-Bus UI review](docs/mobus-ui-review.md) covers variable-height lists, UTF-8-safe text wrapping, scrollbar, bitmap layers, tuner, knob, and the Desktop reference screens. In Studio, choose MO-BUS, activate CONTACTS, use Left/Right on the tuner to select a contact, Up/Down to focus the QSP/CQ knob, and activate to enter CHAT. Up/Down scroll Chat; activate opens COMPOSER. Back restores Chat and CONTACTS. EHAGAKI is also reachable from HOME; arrows move its cursor and Activate cycles tools. After `zig build`, `zig-out/bin/mimoc-studio-snapshot contacts > contacts.pbm` writes a full Studio PBM; `chat`, `composer`, and `ehagaki` are also accepted.

The [CH32V003 integration package](integration/ch32v003/README.md) builds against ch32fun_zig's real SSD1306 page API. [Static Flash/RAM measurements and the hardware verification gate](docs/milestone-7-progress.md) are recorded separately.

Current limits: ASCII bitmap glyphs with one fallback glyph per unsupported UTF-8 codepoint, one root view, a single focus chain, vertical scrolling, and rectangle-based animation. Hardware integration is still pending physical verification; browser support remains future work.
