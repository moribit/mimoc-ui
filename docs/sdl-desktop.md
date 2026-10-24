# Optional SDL3 desktop bridge

The existing native macOS and embedded backends remain unchanged. SDL3 is opt-in:

```
zig build -Dsdl=true check-sdl
zig build -Dsdl=true test-sdl
SDL_VIDEODRIVER=dummy zig build -Dsdl=true test-sdl
```

Install SDL3 (3.2+) and pkg-config. The bridge builds on macOS and Linux and delegates
X11/Wayland/high-DPI/fullscreen to SDL. It initializes video only, never audio.
Applications add `src/platform/sdl/desktop.c`, link SDL3 and libc, and import desktop.zig.
The application owns the event/render loop, framebuffer dimensions, timing and layout.
All SDL calls must run on the main thread. Single-window, at most three texture slots;
a slot's source dimensions must stay constant until close. Input is currently a minimal
Space/focus/F11/Escape window loop, not a complete replacement for the native Desktop text/IME API.
No game state or game timing lives in this module.

`mimoc_sdl_size` reports physical render-output pixels. `mimoc_sdl_present` uploads a row-major
ARGB8888 buffer into a nearest-neighbor texture with an explicit integer scale and destination.
`presentation.integerScale` computes maximum fitting integer scale (zero when 1x cannot fit).
Applications can hide/reposition peripheral surfaces independently of the central surface.
The bridge filters key repeat and reports focus loss so the application can cancel held input.

Reusable raster additions:

- `presentation.rotate`: Mono1 0/90/180/270 degrees; source and destination must not alias.
- `mono1.Renderer.bitmapRotated`: row-MSB bitmap rotation, clip-aware, OR or replace composition.
- `mono1.Renderer.fillCircle`: filled midpoint raster circle.
- `font.drawRotated`: fixed pixel font with rotation and optional opaque background.

Mono1 already supported variable dimensions; no fixed 128x64 assumption was introduced.
Regression tests cover 64x128 rotation and original 128x64 round trip plus clipping.
