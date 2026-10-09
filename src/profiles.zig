/// Suggested capacities. These are ordinary Runtime configurations; they do
/// opt into bounded Desktop input, but never import platform dependencies.
pub const tiny = .{ .max_nodes = 8, .max_animations = 1, .diagnostics = false };
pub const embedded = .{ .max_nodes = 16, .max_animations = 4, .diagnostics = false };
pub const desktop = .{ .desktop_input = true, .max_nodes = 64, .max_animations = 8, .diagnostics = true };
