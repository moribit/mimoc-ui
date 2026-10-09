//! Compiler-semantic expectations, not a handwritten copy of the vendor ABI.
//! The exported constant is read from untouched target-generated C by the gate.
const types = .{
    c_char,      i8,      u8,         c_short,     c_ushort, c_int, c_uint,
    c_long,      c_ulong, c_longlong, c_ulonglong, f32,      f64,   c_longdouble,
    ?*anyopaque, usize,   isize,      isize,       usize,    i8,    u8,
    i16,         u16,     i32,        u32,         i64,      u64,
};
pub export const mimoc_abi_expectations: [types.len * 2]u32 = blk: {
    var values: [types.len * 2]u32 = undefined;
    for (types, 0..) |T, i| {
        values[2 * i] = @sizeOf(T);
        values[2 * i + 1] = @alignOf(T);
    }
    break :blk values;
};

// Exercise aggregate layout as well as scalar assertions. These expected
// offsets are also independently checked by the official C compiler probe.
pub const Mixed = extern struct {
    prefix: u8,
    integer: c_ulonglong,
    number: f64,
    suffix: u8,
};
pub export const mimoc_abi_mixed: Mixed = .{ .prefix = 1, .integer = 2, .number = 3, .suffix = 4 };
pub export const mimoc_abi_mixed_layout: [6]u32 = .{
    @sizeOf(Mixed),              @alignOf(Mixed),            @offsetOf(Mixed, "prefix"),
    @offsetOf(Mixed, "integer"), @offsetOf(Mixed, "number"), @offsetOf(Mixed, "suffix"),
};
