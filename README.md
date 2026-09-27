# Mimoc UI

Small Zig UI core for monochrome embedded displays. The current implementation covers milestones 1–4: fixed-capacity declarative nodes, integer layout, action/focus navigation, SSD1306-format software rendering, headless snapshots, and a macOS virtual display.

```sh
zig build test
zig build run
```

The simulator uses arrow keys or WASD to move focus, Return/Space to activate, and mouse clicks to select buttons. Its display is a 128×64, 1-bit page-order framebuffer scaled 8× with nearest-neighbor pixels.

`src/root.zig` has no libc or third-party dependencies. `src/platform/macos/window.m` is the isolated AppKit window bridge. Rendering the same settled UI one page at a time uses `headless.renderPage` with a 128-byte buffer.

For a small target, use `runtime.beginView()` and `runtime.finishView()` to build directly into runtime storage. `src/embedded_smoke.zig` is a freestanding page-render compilation check. The [Milestone 4 review](docs/milestone-4-review.md) records the RAM budget and the next architecture decisions.

Current limits: ASCII bitmap text, one root view, static layout, and a single focus chain. Animation, transitions, Studio, hardware adapters, and browser support belong to later milestones after architecture review.
