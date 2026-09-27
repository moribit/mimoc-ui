# Milestone 1–4 architecture review

## Implemented boundary

The application builds a fixed-capacity preorder node array using integer IDs. Layout computes integer rectangles. The runtime owns focus, accepts abstract actions, and paints into a Mono1 software surface. The same surface format is used by the headless backend and the macOS simulator. AppKit sees only the 1024-byte page-order framebuffer.

The first API is deliberately explicit: `begin(.column)` / `add` / `end`. This keeps node count and traversal cost visible. An owned `Builder(N)` is convenient for Desktop; `runtime.beginView()` writes into the runtime's node storage so embedded builds do not duplicate the node array. IDs are stable `u16` values supplied by the application.

## RAM model, Zig 0.16 aarch64

| Item | Bytes |
|---|---:|
| One `Node` | 48 |
| `Runtime(16)` | 784 |
| In-place builder temporary | 48 |
| One SSD1306 page buffer | 128 |
| Subtotal with 16 nodes | 960 |
| Full 128×64 framebuffer | 1024 |

The 16-node page-buffer configuration leaves about 1088 bytes of a 2KB RAM device for stack, application state, display driver, and other globals. It is a memory budget, not a claim that the complete CH32V003 integration fits. The smaller `Runtime(8)` sample compiles for `riscv32-freestanding`; hardware RAM/Flash measurement is deferred to Milestone 7.

The runtime has no allocator and the Core does not link libc. Text slices refer to caller-owned immutable memory, normally static strings on embedded targets. Rebuilding an in-place view overwrites the previous nodes, so animation work must retain only the old values it needs, keyed by ID, in a separate bounded presentation table.

## Decisions for Milestone 5

- Keep the application model outside Core. `update(now_ms)` will advance fixed-capacity presentation tracks using elapsed time; rendering must read a frozen presentation snapshot and never advance animations.
- Identity should match previous and current layout by `u16` ID with a bounded linear scan. Duplicate IDs should be rejected during view finalization.
- Introduce a bounded render-command list only if it avoids storing another full tree. Direct traversal of immutable presentation nodes is acceptable for page rendering.
- Transitions should initially change position and clipping. A 1-bit surface cannot represent continuous opacity.
- The current `Runtime(16)` includes frames in every node. If the CH32V003 integration runs short of stack or RAM, reduce node capacity or split immutable view descriptors from compact layout records before adding animation state.

## Current limits

One root view, single focus chain, uppercase-oriented ASCII bitmap glyphs, and static layout. Page rendering is deterministic for a settled view and tested byte-for-byte against full-frame rendering. Desktop compilation and process launch were verified; visual window inspection was not available through the app inventory in this environment. Studio and device integration remain gated on the later architecture review and milestones.
