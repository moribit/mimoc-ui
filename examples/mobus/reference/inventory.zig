//! Phase 2 state backlog from the pinned current screen call sites.
//! These are catalog entries, not passing render programs or placeholder goldens.
pub const Entry = struct { name: []const u8, renderer: []const u8, screen: []const u8, states: []const []const u8 };
pub const unverified = [_]Entry{
    .{ .name = "contact-action", .renderer = "contact_action_renderer.hpp / display_facade.cpp", .screen = "contact_book_screen.hpp", .states = &.{ "friend-code", "sending", "pending-list", "pending-confirm", "slot-select", "empty", "offline" } },
    .{ .name = "message-box", .renderer = "render_message_box", .screen = "message_box_screen.hpp", .states = &.{ "loading", "default", "scrolled", "sender-changed", "outgoing", "japanese", "notice", "compose" } },
    .{ .name = "chat-composer", .renderer = "make_open_chat_composer_render_api", .screen = "open_chat_screen.hpp", .states = &.{ "empty", "draft", "morse-preview", "japanese" } },
    .{ .name = "language", .renderer = "make_language_dialog_render_api", .screen = "setting_screen.hpp / factory_setup_screen.hpp", .states = &.{ "english", "japanese", "confirm" } },
    .{ .name = "sound", .renderer = "make_sound_settings_render_api", .screen = "setting_screen.hpp", .states = &.{ "enabled", "disabled", "volume", "tone" } },
    .{ .name = "boot-sound", .renderer = "make_boot_sound_render_api", .screen = "setting_screen.hpp", .states = &.{ "selected", "preview" } },
    .{ .name = "setting-info", .renderer = "firmware_info / text_modal / list / text_input", .screen = "setting_screen.hpp", .states = &.{ "firmware", "rtc", "ota-manifest", "mobus-info", "error", "update-status" } },
    .{ .name = "contact-confirm", .renderer = "render_friend_request_confirm", .screen = "contact_book_screen.hpp", .states = &.{ "no", "yes", "unknown-name" } },
    .{ .name = "cq-chat", .renderer = "render_realtime_talk / render_realtime_scan", .screen = "cq_chat_screen.hpp", .states = &.{ "waiting", "incoming", "connecting", "connected", "local-cursor", "remote-text", "language-overlay", "error" } },
    .{ .name = "realtime", .renderer = "render_realtime_scan / render_realtime_talk", .screen = "realtime_talk_screen.hpp", .states = &.{ "scan-phase-0", "scan-phase-1", "scan-phase-2", "scan-phase-3", "peer-list", "busy-peer", "incoming", "connecting", "talk", "error" } },
    .{ .name = "talk-edit", .renderer = "render_talk_input", .screen = "message_box_screen.hpp", .states = &.{ "draft", "cursor", "status", "language-overlay", "inverse", "transition-offset" } },
    .{ .name = "ehagaki-viewer", .renderer = "render_ehagaki_viewer", .screen = "ehagaki_screen.hpp", .states = &.{ "front", "back", "text-scroll", "flip", "page-overlay", "sync-notice", "text-reveal" } },
    .{ .name = "ehagaki-edit", .renderer = "render_ehagaki_text_input / render_ehagaki_canvas", .screen = "ehagaki_screen.hpp", .states = &.{ "english-title", "japanese-title", "body", "cursor", "character-count", "bitmap", "tool-menu", "stroke-menu", "undo-redo" } },
    .{ .name = "ehagaki-confirm", .renderer = "render_ehagaki_post_confirm / render_ehagaki_public_confirm", .screen = "ehagaki_screen.hpp", .states = &.{ "post", "public-no", "public-yes" } },
    .{ .name = "draw", .renderer = "render_draw_canvas / render_canvas_side_menu", .screen = "draw_screen.hpp", .states = &.{ "bitmap", "cursor", "anchor-line", "anchor-rect", "filled-rect", "tools", "colour", "stroke-popup", "toast" } },
    .{ .name = "synth", .renderer = "render_synth_sequencer", .screen = "synth_screen.hpp", .states = &.{ "edit-page-0", "edit-page-1", "playing", "track", "note", "tempo", "pattern-load", "pattern-save", "confirm", "error" } },
    .{ .name = "factory", .renderer = "render_setup_morse_hello / language / wifi / status", .screen = "factory_setup_screen.hpp", .states = &.{ "hello-t0", "hello-progress", "hello-settled", "language", "scan", "ssid", "password", "connecting", "confirm", "complete", "error" } },
    .{ .name = "watch", .renderer = "legacy/screens/oled_view.hpp", .screen = "menu_screen / app-shell", .states = &.{ "time", "time-unavailable", "lock", "charging", "notification", "boot-logo" } },
    .{ .name = "game", .renderer = "render_game_trainer / render_game_clear", .screen = "game_screen.hpp/.cpp", .states = &.{ "target", "progress", "morse", "clear", "new-record" } },
    .{ .name = "typing-word", .renderer = "render_typing_select / word / result", .screen = "game_screen.hpp/.cpp", .states = &.{ "selector", "target", "input-position", "score", "miss", "result" } },
    .{ .name = "arcade", .renderer = "render_arcade", .screen = "arcade_screen.hpp/.cpp", .states = &.{ "title", "playing", "game-over", "best" } },
    .{ .name = "low-battery", .renderer = "render_low_battery_warning / charging_standby", .screen = "app-shell maintenance", .states = &.{ "warning", "charging", "resume" } },
    .{ .name = "ota", .renderer = "display_render_ota_progress", .screen = "setting_screen / update callbacks", .states = &.{ "starting", "downloading", "retry", "validating-failed", "hash-failed", "server-incompatible", "rebooting", "failed" } },
};
