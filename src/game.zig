const std = @import("std");
const testing = std.testing;

pub const Unit = struct { id: u32, hp: u32, x: u32, y: u32 };

pub const Field = struct { unit_id: ?u32, res_hp: ?u32 };

pub const Board = struct {
    fields: []Field,
    x: u32,
    y: u32,
    allocator: std.mem.Allocator,

    pub fn init(x: u32, y: u32, allocator: std.mem.Allocator) !Board {
        const b = Board{ .fields = try allocator.alloc(Field, x * y), .x = x, .y = y, .allocator = allocator };
        errdefer allocator.free(b.fields);
        for (b.fields) |*f| {
            f.* = Field{ .unit_id = null, .res_hp = null };
        }
        return b;
    }

    pub fn getField(self: *Board, x: u32, y: u32) *Field {
        return &self.fields[x * self.y + y];
    }

    pub fn deinit(self: *Board) void {
        self.allocator.free(self.fields);
    }
};

pub const Game = struct {
    board: Board,
    units: std.AutoHashMap(u32, Unit),

    pub fn init(x: u32, y: u32, allocator: std.mem.Allocator) !Game {
        return Game{ .board = try Board.init(x, y, allocator), .units = std.AutoHashMap(u32, Unit).init(allocator) };
    }

    pub fn newUnit(self: *Game, unit: Unit) void {
        self.units.put(unit.id, unit);
    }

    pub fn deinit(self: *Game) void {
        self.units.deinit();
        self.board.deinit();
    }
};

test "board" {
    const ally = testing.allocator;

    var brd = try Board.init(128, 128, ally);
    try testing.expectEqual(128 * 128, brd.fields.len);

    brd.getField(10, 10).res_hp = 100;
    try testing.expectEqual(100, brd.getField(10, 10).res_hp);
    defer brd.deinit();
}

test "game" {
    const ally = testing.allocator;
    var game = try Game.init(342, 267, ally);
    defer game.deinit();

    try testing.expectEqual(342 * 267, game.board.fields.len);
}
