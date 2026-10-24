//! Thin SDL3 bridge. All coordinates and destination sizes use physical pixels.
pub extern fn mimoc_sdl_open([*:0]const u8, c_int) c_int;
pub extern fn mimoc_sdl_error() [*:0]const u8;
pub extern fn mimoc_sdl_close() void;
pub extern fn mimoc_sdl_poll() c_int;
pub extern fn mimoc_sdl_time() u64;
pub extern fn mimoc_sdl_delay() void;
pub extern fn mimoc_sdl_fullscreen() void;
pub extern fn mimoc_sdl_size(*c_int, *c_int) void;
pub extern fn mimoc_sdl_begin() void;
pub extern fn mimoc_sdl_present(c_int, [*]const u32, c_int, c_int, c_int, c_int, c_int) c_int;
pub extern fn mimoc_sdl_end() void;
