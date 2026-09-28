# Widget and Navigation review

## Architecture

The Core still uses Zig and `std` only. Widgets store no application value. Checkbox and Toggle activation returns the focused `u16` ID; the application changes its own state and rebuilds. Icon, Checkbox, Toggle, Progress, Clip, Scroll, and ListItem use compact `Node.Kind` values without adding a field to `Node`. Toggle and Progress use existing primitive children so their moving/filling rectangle uses the existing presentation track. Panel is a Stack/Rect/Column/Text/Divider composite. A titled Panel costs five nodes before content; Checkbox and Icon cost one, Toggle and Progress three each, and a ListItem one.

`Runtime.render()` and `renderShifted()` are read-only. The latter enables a single-view screen slide. `Transition.Pair` accepts two caller-owned runtimes for larger targets; the Core does not allocate a second runtime. `Transition.update(now_ms)` freezes the offset before all SSD1306 pages are rendered. Float math is absent from the Core.

Clip is a View container. During rendering, each node's clip is the intersection of its Clip/Scroll ancestors and the viewport. A parent's presentation translation applies to descendants, so animating the List content column also animates its items. Clip state is computed from parent indexes; there is no renderer clip stack or retained second tree.

## Public API

- `widgets.icon`, `checkbox`, `toggle`, `progress`, `beginPanel`/`endPanel`, `beginClip`, `beginScroll`, `beginList`/`listItem`/`endList` operate on `Builder` or `InPlaceBuilder`.
- `theme.WidgetStyle` holds padding, spacing, border and animation defaults. `widgets.Icon` accepts ROM-backed row-major bitmap bytes and dimensions; standard 8×8 symbols are in `widgets.icons`.
- `scroll.ScrollState` is application-owned. `Runtime.ensureFocusVisible(scroll_id, &offset)` adjusts it after focus navigation; rebuild the View to apply the new offset. `scroll.visibleRange` helps applications enumerate a bounded range of fixed-height items.
- `navigation.Navigation(Screen, capacity)` holds a fixed-capacity application-owned stack with `push`, `pop`, `replace`, `reset`, `current`, `depth`, `remember`, `entry`, and `handleBack`. Each entry can restore focus ID and scroll offset.
- `transition.Transition` supports `none`, four slide directions, and `none`/`single_view`/`full` capabilities. `Shifted` renders one runtime; `Pair` renders two caller-owned runtimes.

Composite helpers reserve adjacent IDs (`toggle`/`progress`: `id..id+2`; titled `panel`: `id..id+4`). The caller must keep these ranges distinct. `finishView()` rejects duplicate IDs.

## RAM measurements

`zig run src/footprint.zig` on macOS/aarch64 and compile-time RV32 size probing with Zig 0.16 ReleaseSmall:

| Type | macOS bytes | generic RV32 bytes |
|---|---:|---:|
| Node | 48 | 40 |
| Runtime(16 nodes, 4 tracks) | 936 | 804 |
| InPlaceBuilder(16) | 48 | 40 |
| AnimationTrack | 36 | 36 |
| NavigationEntry with `enum(u8)` | 8 | 8 |
| Navigation(8) with `enum(u8)` | 66 | 66 |
| ScrollState | 2 | 2 |
| Transition | 24 | 24 on macOS; RV32 not separately probed |

The existing CH32V003 firmware integration measured `Runtime(16,4)` as **808B** with its RV32EC target and toolchain configuration, so the embedded budget uses that more conservative value. With an 8-entry navigation stack, a 40B in-place builder, 2B scroll state, 24B transition estimate, and 128B page buffer, the representative subtotal is **1068B**, leaving about **980B** of 2KB for application state, stack, and driver data. A 3-entry navigation stack saves 40B. This is a size estimate, not hardware stack or speed measurement. The existing hardware integration remains unverified because the board and programmer are unavailable.

## Verification

- `zig build test` and `zig build test -Doptimize=ReleaseSmall` pass.
- `zig build` produces the macOS Simulator and Studio binaries.
- `zig build-obj src/widget_embedded_smoke.zig -target riscv32-freestanding -O ReleaseSmall` compiles the no-allocator page-render path with widgets, scroll, navigation and transition.
- Tests cover Checkbox's four states and activation ID, Toggle and Progress animation midpoint, Progress endpoints, Icon dimensions and edge clipping, Panel title variants, nested Clip, Scroll offset and focus visibility, ListItem focus and fixed-height visible range, Navigation stack operations and restoration, slide directions and low-FPS completion, and full-frame/eight-page byte equivalence during widget animation and both single/two-view transitions.
- A Studio test switches demos and navigates Home → Contacts → Home. A separate showcase test goes Home → Contacts → Chat → Back and checks focus and scroll restoration.

## Limitations and Mo-Bus work

Scrolling is vertical with no inertia. `visibleRange` assumes fixed-height rows; the application remains responsible for adding appropriate top/bottom space if it builds only that subset. The default single-view transition shows only the incoming screen during the slide. A two-view slide requires two caller-owned runtimes and is intended for Desktop/ESP32, not the CH32V003 baseline. Text remains ASCII bitmap text; dynamic text storage belongs to the application.

For Mo-Bus, map joystick/buttons to existing Actions, choose screen-specific capacities, and measure font coverage, variable-height contacts/chat rows, stack high-water, Flash, and eight-page render time on real devices. The current CH32V003 integration has compile/link measurements only; no hardware visual or timing verification is claimed here.
