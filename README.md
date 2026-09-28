# Mimoc UI

Small Zig UI core for monochrome embedded displays. The implementation includes fixed-capacity declarative nodes, integer layout, action/focus navigation, SSD1306-format software rendering, headless snapshots, a macOS virtual display, time-based animation, and Mimoc UI Studio.

```sh
zig build test
zig build run
zig build studio
```

The simulator uses arrow keys or WASD to move focus, Return/Space to activate, Escape to go back, and mouse clicks to select controls. Press M to cycle through the classic, Widgets, and Navigation demos. Its display is a 128×64, 1-bit page-order framebuffer scaled 8× with nearest-neighbor pixels.

`src/root.zig` has no libc or third-party dependencies. `src/platform/macos/window.m` is the isolated AppKit window bridge. Rendering the same settled UI one page at a time uses `headless.renderPage` with a 128-byte buffer.

For a small target, use `runtime.beginView()` and `runtime.finishView()` to build directly into runtime storage. `src/embedded_smoke.zig` is a freestanding page-render compilation check. The [Milestone 4 review](docs/milestone-4-review.md) records the RAM budget and the next architecture decisions.

Use `Runtime(.{ .max_nodes = 16, .max_animations = 4 })` and set a node's `.animation` to a compact `Animation` value. Call `runtime.update(now_ms)` once per frame, then render the full framebuffer or each page without changing the time. The [Milestone 5 review](docs/milestone-5-review.md) records measured sizes and verification.

[Studio](docs/milestone-6-review.md) uses Mimoc UI for its own controls and a separate preview Runtime. Its FPS setting changes the update cadence; Pause and Step use a manual clock.

The [Widget and Navigation review](docs/widget-navigation-review.md) describes Checkbox, Toggle, Progress, Icon, Panel, Clip, ScrollView, List, fixed-capacity Navigation, and screen transitions. In Studio, the DEMO control cycles through the same three demos as the simulator.

The [CH32V003 integration package](integration/ch32v003/README.md) builds against ch32fun_zig's real SSD1306 page API. [Static Flash/RAM measurements and the hardware verification gate](docs/milestone-7-progress.md) are recorded separately.

Current limits: ASCII bitmap text, one root view, a single focus chain, vertical scrolling, and rectangle-based animation. Hardware integration is still pending physical verification; browser support remains future work.
