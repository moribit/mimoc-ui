const Mono1 = @import("../surface.zig").Mono1;
const Renderer = @import("mono1.zig").Renderer;

pub fn render(ui: anytype, bytes: []u8, width: i16, height: i16) error{InvalidSize}!void {
    var surface = try Mono1.init(bytes, width, height);
    surface.clear(false);
    var renderer = Renderer.init(&surface);
    ui.render(&renderer);
}
pub fn renderPage(ui: anytype, bytes: []u8, width: i16, page_index: u8) error{InvalidSize}!void {
    var surface = try Mono1.page(bytes, width, page_index);
    surface.clear(false);
    var renderer = Renderer.init(&surface);
    ui.render(&renderer);
}
