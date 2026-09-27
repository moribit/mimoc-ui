# Milestone 6 architecture review

## Studio architecture

The Studio window is a 384×192 Mono1 surface enlarged 3× by the same AppKit bridge as the 128×64 Simulator. Its controls, labels, borders, and panels are a normal `Runtime(64)` view rendered by Mimoc UI. A separate `Runtime(.{ .max_nodes = 16, .max_animations = 4 })` builds the shared `examples/demo_view.zig` preview and renders into a 1024-byte SSD1306-format framebuffer. Desktop-only composition copies those bits into the Studio surface at 1× or 2×. No renderer specialization or allocation was added to Core.

Controls: Run, Pause, Restart, Step +16ms, FPS cycle (60/30/15/10), target-profile cycle, bounds overlay, and preview-scale toggle. The right panel shows FPS, frame, node and active-animation counts, focus, last Action, runtime bytes, buffer bytes, estimated remaining CH32V003 RAM, selected node, and scale. Preview clicks select nodes; clicking a preview button also moves focus. Keyboard arrows/WASD operate the preview. R/P/X/N/F/T/O/Z trigger Studio controls.

The Studio owns a manual logical `u32` clock. While running it advances that clock only at the selected FPS cadence, using elapsed monotonic macOS time. Pause stops updates; Step advances exactly 16ms. Restart resets the preview Runtime and clock. The same preview definition runs in the original Simulator.

The optional overlay is composed after the preview framebuffer, so bounds, focus selection, node IDs, and viewport clipping outline do not alter the Preview Runtime's own framebuffer. Rendering both Runtime instances remains read-only.

## RAM and dependencies

| Item | aarch64 Zig 0.16 |
|---|---:|
| `Node` | 48B |
| `Track` | 36B |
| Studio UI `Runtime(64)` | 3096B |
| Preview `Runtime(16,4)` | 936B |
| Complete Studio state, including both framebuffers | 14576B |

These larger capacities and buffers are Desktop-only. The embedded Core path and its 1112B 16-node/4-track/page-buffer budget are unchanged. Studio uses no external package. Core still requires no allocator or libc and uses no floating point; AppKit supplies the monotonic clock outside Core.

## Verification and limits

`zig build test` includes Studio cadence checks for 60/30/15/10 FPS, pause, and manual Step. `zig build` compiles both Simulator and Studio; `zig build studio` launches a persistent macOS process. The current UI automation inventory does not expose these unbundled command-line AppKit windows, so a visual inspection of Studio controls remains outstanding.

Target profiles currently supply metadata and a RAM estimate. They do not emulate device CPU timing, Flash limits, or hardware input. The CH32V003 remaining-RAM line subtracts runtime, in-place builder, and 128-byte page buffer from 2048B; application state, driver state, and stack are not included. These must be measured during Milestone 7.
