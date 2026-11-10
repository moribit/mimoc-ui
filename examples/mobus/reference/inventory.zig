//! Remaining P1/P2 edge coverage from the pinned current screen call sites.
//! These are catalog entries, not passing render programs or placeholder goldens.
pub const Entry = struct { name: []const u8, renderer: []const u8, screen: []const u8, states: []const []const u8 };
pub const unverified = [_]Entry{
    .{ .name = "contact-action", .renderer = "contact_action_renderer.hpp / display_facade.cpp", .screen = "contact_book_screen.hpp", .states = &.{ "friend-code", "sending", "pending-list", "pending-confirm", "slot-select", "empty", "offline" } },
    .{ .name = "language", .renderer = "make_language_dialog_render_api", .screen = "setting_screen.hpp / factory_setup_screen.hpp", .states = &.{ "confirm" } },
    .{ .name = "sound", .renderer = "make_sound_settings_render_api", .screen = "setting_screen.hpp", .states = &.{ "enabled", "disabled", "volume", "tone" } },
    .{ .name = "boot-sound", .renderer = "make_boot_sound_render_api", .screen = "setting_screen.hpp", .states = &.{ "selected", "preview" } },
    .{ .name = "contact-confirm", .renderer = "render_friend_request_confirm", .screen = "contact_book_screen.hpp", .states = &.{ "no", "yes", "unknown-name" } },
    .{ .name = "draw", .renderer = "render_draw_canvas / render_canvas_side_menu", .screen = "draw_screen.hpp", .states = &.{ "tools", "colour", "stroke-popup", "toast" } },
    .{ .name = "watch", .renderer = "legacy/screens/oled_view.hpp", .screen = "menu_screen / app-shell", .states = &.{ "time", "time-unavailable", "lock", "charging", "notification", "boot-logo" } },
    .{ .name = "game", .renderer = "render_game_trainer / render_game_clear", .screen = "game_screen.hpp/.cpp", .states = &.{ "target", "progress", "morse", "clear", "new-record" } },
    .{ .name = "typing-word", .renderer = "render_typing_select / word / result", .screen = "game_screen.hpp/.cpp", .states = &.{ "selector", "target", "input-position", "score", "miss", "result" } },
    .{ .name = "arcade", .renderer = "render_arcade", .screen = "arcade_screen.hpp/.cpp", .states = &.{ "title", "playing", "game-over", "best" } },
    .{ .name = "low-battery", .renderer = "render_low_battery_warning / charging_standby", .screen = "app-shell maintenance", .states = &.{ "warning", "charging", "resume" } },
    .{ .name = "ota", .renderer = "display_render_ota_progress", .screen = "setting_screen / update callbacks", .states = &.{ "starting", "downloading", "retry", "validating-failed", "hash-failed", "server-incompatible", "rebooting", "failed" } },
};
