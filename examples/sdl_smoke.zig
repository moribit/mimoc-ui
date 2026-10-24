//! Optional SDL integration probe: works under Xvfb or SDL_VIDEODRIVER=dummy.
const desktop = @import("desktop");
extern fn mimoc_sdl_test_key(c_int, c_int) void;
extern fn mimoc_sdl_test_focus() void;
pub fn main() !void {
    if (desktop.mimoc_sdl_open("mimoc-ui SDL smoke", 0) == 0) return error.WindowFailed;
    defer desktop.mimoc_sdl_close();
    var pixels: [64 * 128]u32 = @splat(0xffeeeeee);
    for (0..4) |_| {
        desktop.mimoc_sdl_begin();
        if (desktop.mimoc_sdl_present(0, &pixels, 64, 128, 0, 0, 1) == 0) return error.PresentFailed;
        desktop.mimoc_sdl_end();
    }
    while (desktop.mimoc_sdl_poll() != 0) {}
    mimoc_sdl_test_key(1, 1);
    var event = desktop.mimoc_sdl_poll();
    while (event != 0) : (event = desktop.mimoc_sdl_poll()) {
        if (event == 2) return error.RepeatedSpace;
    }
    mimoc_sdl_test_key(1, 0);
    try expectEvent(2);
    mimoc_sdl_test_key(0, 0);
    try expectEvent(3);
    mimoc_sdl_test_focus();
    try expectEvent(4);
    desktop.mimoc_sdl_fullscreen();
    var w: c_int = 0;
    var h: c_int = 0;
    desktop.mimoc_sdl_size(&w, &h);
    if (w <= 0 or h <= 0) return error.InvalidViewport;
}

fn expectEvent(expected: c_int) !void {
    for (0..256) |_| {
        const event = desktop.mimoc_sdl_poll();
        if (event == expected) return;
        desktop.mimoc_sdl_delay();
    }
    return error.MissingEvent;
}
