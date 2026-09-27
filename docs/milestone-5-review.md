# Milestone 5 architecture review

## Implemented architecture

`Runtime(.{ .max_nodes = 16, .max_animations = 4 })` retains one Node array and a bounded table of presentation tracks. `beginView()` captures only the current rectangles of previously animated IDs before the in-place builder overwrites nodes. `finishView()` validates unique IDs, lays out the new model, and starts or retargets tracks when an animated ID's visual rectangle changes. A new view starts at its final rectangle. Retargeting begins at the current presentation rectangle, not the previous model target.

`update(now_ms)` is the only operation that advances tracks. It receives a caller-owned monotonic `u32` millisecond clock and uses wrapping subtraction. Each track stores `from`, `to`, frozen `current`, start time, compact animation specification, and ID. Rendering only reads `current`; eight pages of one frame therefore share one presentation snapshot. Integer fixed-point progress and easing implement linear, ease in, ease out, ease in/out, and a bounded spring overshoot. `Node.offset` contributes to the visual rectangle, so layout position, size, and offset changes use the same interpolation path.

The macOS bridge passes `NSProcessInfo.systemUptime` to the Core and schedules redraw ticks. The demo has an independent 2×10 selection marker that slides among CHAT, CQ, and EHAGAKI.

## API and RAM

| Item | Before M5 | After M5, aarch64 Zig 0.16 |
|---|---:|---:|
| `Node` | 48B | 48B |
| `Animation` descriptor | — | 4B, stored in Node |
| `Track` | — | 36B |
| `Runtime(16)` / `Runtime(16,4)` equivalent | 784B | `Runtime(16,4)` = 936B |
| In-place builder | 48B | 48B |
| SSD1306 page buffer | 128B | 128B |
| Embedded working subtotal | 960B | 1112B |

The subtotal leaves **936B** from CH32V003's 2048B RAM for application state, stack, and driver storage. This is a budget estimate, not a hardware fit claim. The Node remains 48B by using a `u16` parent-index sentinel and arranging fields to avoid padding. No previous Node array is retained. Core requires no allocator, libc, or floating-point operation. The desktop clock conversion uses a floating-point OS value outside Core.

## Verification

- `zig build test` and `zig build test -Doptimize=ReleaseSmall`: linear midpoint/end, monotonic ease curves, spring endpoints/overshoot, low-FPS and delayed final update, clock wraparound, in-flight retargeting, size interpolation, duplicate ID rejection, exact RAM-size assertions, and animated full-frame/eight-page byte equivalence.
- `zig build`: macOS Simulator compiled and process launched. The GUI window could not be selected by the available app inventory, so visual animation inspection remains unverified.
- `zig build-obj src/embedded_smoke.zig -target riscv32-freestanding -O ReleaseSmall` and a freestanding `zig build-exe -fno-entry` link: successful with animation, in-place rebuild, update, and page rendering in the compiled path. Zig supplies compiler runtime helpers; no libc is linked.

## Limits and Milestone 6 gate

Only nodes carrying an animation specification in the previous view are captured before an in-place rebuild. Introduce animation on a previously static ID using the owned builder path or retain the modifier across states. When more than `max_animations` animated IDs exist, later IDs snap to target. IDs must be unique; validation is bounded quadratic work over the small node array. Track storage persists for animated IDs even while idle, though `activeAnimationCount()` counts only moving tracks.

The 936B Runtime fits the provisional budget, so Studio can use a larger Desktop profile while preserving the small embedded configuration. Before CH32V003 hardware integration, measure real stack use and reduce capacities if the remaining 936B is insufficient. Studio must keep its own UI runtime separate from its preview runtime and feed a manual or cadence-limited clock to the preview.
