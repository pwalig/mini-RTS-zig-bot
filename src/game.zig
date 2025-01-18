const std = @import("std");
const testing = std.testing;

const field = struct { unit_id: ?u32, res_hp: u8 };

pub const board = struct {
    fields: []field,
    x: u32,
    y: u32,

    pub fn init(x: u32, y: u32, allocator: std.mem.Allocator) std.mem.Allocator.Error!board {
        const b = board{ .fields = try allocator.alloc(field, x * y), .x = x, .y = y };
        errdefer allocator.free(b.fields);
        for (b.fields) |*f| {
            f.* = field{ .unit_id = null, .res_hp = 0 };
        }
        return b;
    }

    pub fn deinit(self: board, allocator: std.mem.Allocator) void {
        allocator.free(self.fields);
    }
};

test "creation" {
    const ally = testing.allocator;

    const brd = try board.init(128, 128, ally);
    try testing.expectEqual(128 * 128, brd.fields.len);
    defer brd.deinit(ally);
}
