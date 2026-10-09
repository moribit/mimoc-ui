//! Application-owned, fixed dummy data, shared by Reference and Candidate.
pub const Message = struct { sender: []const u8, text: []const u8, mine: bool = false };
pub const Fixture = struct {
    battery_percent: u8 = 73,
    charging: bool = false,
    radio_level: u8 = 3,
    time: []const u8 = "12:34:56",
    contact: []const u8 = "Hazuki",
    room: []const u8 = "OPEN CHAT",
};
pub const defaults: Fixture = .{};
pub const chat = [_]Message{ .{ .sender = "Hazuki", .text = "Hello" }, .{ .sender = "Me", .text = "CQ" } };
pub const japanese = [_]Message{ .{ .sender = "はづき", .text = "こんにちは 沖縄" }, .{ .sender = "私", .text = "CQやりませんか？", .mine = true } };
pub const long_chat = [_]Message{.{ .sender = "Hazuki", .text = "Hello world this is a long message wrapping across several lines" }};
