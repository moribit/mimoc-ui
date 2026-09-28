# API stabilization review

## Architecture and API

The new `ui.Ui(Id, config)` layer wraps the existing in-place Builder. Application IDs may be `enum(u16)` or raw `u16`; nested component scopes derive stable `u16` Node IDs from parent key, logical ID, and composite role. A bounded scan detects collisions before append. There is no dynamic map, previous Node tree, allocator, runtime reflection, or platform import. Existing `Runtime.beginView`, `view.begin/add/end`, and `finishView` remain available.

High-level `column`, `row`, `stack`, `clip`, `scrollView`, `list`, and `panel` return a small guard closed with `defer guard.end()`. Leaf calls do not return error unions. `finishChecked()` reports capacity, collision, hierarchy, and animation errors in tests; `finish()` panics in Debug and traps in ReleaseSmall. Diagnostic builds can inspect failure, used/capacity, widget, screen, and ID. Core `resources()`, `nodeUsage()`, `animationUsage()`, and Navigation `usage()` report current capacity. Presets in `profiles.zig` provide tiny, embedded, and desktop configurations without changing Core behavior.

Classic Simulator, Widgets, Navigation, Studio chrome, and the Mo-Bus reference demo now build through the high-level API. `src/widget_embedded_smoke.zig` remains a low-level reference. Components are ordinary Zig functions (`docs/components.md`). The Studio inspector shows node/animation/navigation used and maximum, focus, selected Node, Runtime and buffer bytes, and optional selected Node details. Its overlay marks bounds, clip/scroll viewport, focused and selected nodes, and Node IDs in the Studio composition buffer; the 128×64 Preview framebuffer is unchanged.

## Animation and identity

At `beginView`, the Runtime stores only each old ID and presentation Rect when animation capacity is nonzero. This fixes static → animated transitions, including retargeting from the current presentation. It does not keep a second Node array. `update(now_ms)` alone advances tracks; `render()` remains read-only. Identical logical IDs retain focus and animation across rebuilds. An internal role change does not alter a widget's public key. Because IDs are 16-bit, derived keys can collide; the view build reports this explicitly. An application can choose distinct IDs/scopes to resolve a rare collision.

## Memory

Measured with Zig 0.16.0. Values include track storage inside Runtime.

| Type | macOS arm64 before | macOS arm64 after | RV32 after |
| --- | ---: | ---: | ---: |
| Node | 48 | 48 | 40 |
| Track | 36 | 36 | 36 |
| Runtime(8,1) | — | 528 | 460 |
| Runtime(16,4) | 936 | 1096 | 968 |
| Runtime(32,4) | 1704 | 2024 | 1768 |
| Runtime(64,8) | 3384 | 4024 | — |
| InPlaceBuilder(8) | — | 32 | 24 |
| InPlaceBuilder(16) | 48 | 48 | 40 |
| High-level Ui(8) including builder | — | 48 | 36 |
| High-level Ui(16) including builder | — | 64 | 52 |

The previous metadata adds about 10 bytes per Node plus alignment when tracks are enabled; Runtime(16,4) grows 160B on arm64 and 164B on RV32. With zero animation capacity, the array is compile-time omitted. The RV32 8-node/1-track example totals 652B for Runtime, high-level Ui, three-entry Navigation, ScrollState, and 128B page buffer, leaving 1396B of CH32V003 RAM before application state, driver, and stack. The 16-node/4-track example with five-entry Navigation and Transition totals 1216B, leaving 832B. Prefer the 8-node configuration on CH32V003 until stack and firmware globals are measured.

`zig build resource-report` reports ABI sizes. `tools/ch32-reference-regression.sh` compares an externally built firmware ELF/BIN against the existing ch32-mimoc-ui reference (13,844B Flash image, 516B static RAM). No new linked CH32 firmware or hardware stack measurement was made in this repository; the new high-level path compiled for `riscv32-freestanding -O ReleaseSmall` in `src/ui_embedded_smoke.zig`. Hardware stack watermark guidance is in `docs/embedded-guide.md`.

## Validation and limits

`zig build test` covers typed/raw/scoped identity, collision, scope errors, exact and exceeded capacity, focus rebuild/removal, composite identity, static/animated/retarget animation, animation overflow, full-frame versus independent SSD1306 pages, Studio inspector/overlay, navigation, and existing widgets. `zig build` produces the Simulator, Studio, and headless Studio snapshot. The Studio PBM was inspected at 704×336 with visible preview, controls, and inspector.

The high-level API is additive. `Ui(Id, config)` must use the same compile-time `config` value as its Runtime, including diagnostic option. Diagnostic labels remain in Debug/Desktop when enabled; `profiles.tiny` omits them. The short-ID hash is deterministic and checked, but cannot guarantee collision-free arbitrary trees. Full Flash and stack regressions require rebuilding and measuring the separate CH32 reference firmware. The external AppKit executable links libc for macOS; Core does not.
