const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const distance = @import("coordinateOps.zig").distance;
const coords = @import("coordinateOps.zig").coords;

pub const Unit = struct { id: u32 = undefined, hp: u32 = undefined, x: u32 = undefined, y: u32 = undefined, owner: u32 = undefined };

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

    pub fn getClosestResourceFieldPosition(self: *Board, x: u32, y: u32) ?coords {
        // TO DO write optimal version
        //var dist: u32 = 0;
        //const curField = self.getField(x, y);
        //if (curField.res_hp) |_| return curField;
        //dist += 1;
        //...
        //return null;

        var minDist = self.x + self.y;
        var bestField: ?coords = null;
        for (0..self.y) |yi| {
            for (0..self.x) |xi| {
                const f = self.getField(@intCast(xi), @intCast(yi));
                if (f.res_hp != null) {
                    const dist = distance(x, y, @intCast(xi), @intCast(yi));
                    if (dist < minDist) {
                        minDist = dist;
                        bestField = coords{ .x = @intCast(xi), .y = @intCast(yi) };
                    }
                }
            }
        }
        return bestField;
    }

    pub fn clear(self: *Board) void {
        for (0..self.y) |yi| {
            for (0..self.x) |xi| {
                self.fields[xi * self.y + yi].res_hp = null;
                self.fields[xi * self.y + yi].unit_id = null;
            }
        }
    }

    pub fn printUnits(self: *Board, game: *Game) void {
        for (0..self.y) |yi| {
            for (0..self.x) |xi| {
                const f = self.getField(@intCast(xi), @intCast(yi));
                if (f.unit_id) |id| {
                    print("{d}", .{game.units.get(id).?.owner});
                } else print("-", .{});
            }
            print("\n", .{});
        }
    }

    pub fn printResources(self: *Board) void {
        for (0..self.y) |yi| {
            for (0..self.x) |xi| {
                const f = self.getField(@intCast(xi), @intCast(yi));
                if (f.res_hp) |_| {
                    print("#", .{});
                } else print("-", .{});
            }
            print("\n", .{});
        }
    }

    pub fn deinit(self: *Board) void {
        self.allocator.free(self.fields);
    }
};

pub const Player = struct {
    name: std.ArrayList(u8),
    units: std.AutoHashMap(u32, Unit),
    id: u32,

    pub fn init(name: []const u8, id: u32, allocator: std.mem.Allocator) !Player {
        var p = Player{ .name = try std.ArrayList(u8).initCapacity(allocator, name.len), .units = std.AutoHashMap(u32, Unit).init(allocator), .id = id };
        p.name.appendSliceAssumeCapacity(name);
        return p;
    }

    pub fn newUnit(self: *Player, unit: *Unit) !void {
        unit.owner = self.id;
        try self.units.put(unit.id, unit.*);
    }

    pub fn deinit(self: *Player) void {
        self.name.deinit();
        self.units.deinit();
    }
};

pub const Game = struct {
    board: Board,
    players: std.ArrayList(Player),
    units: std.AutoHashMap(u32, Unit),
    nextPlayerId: u32 = 0,

    pub fn init(x: u32, y: u32, allocator: std.mem.Allocator) !Game {
        return Game{ .board = try Board.init(x, y, allocator), .units = std.AutoHashMap(u32, Unit).init(allocator), .players = std.ArrayList(Player).init(allocator) };
    }

    pub fn findPlayer(self: *Game, playerName: []const u8) ?*Player {
        for (self.players.items) |*player| {
            if (std.mem.eql(u8, player.name.items, playerName)) return player;
        }
        return null;
    }

    pub fn findPlayerArrayPosition(self: *Game, playerName: []const u8) ?u32 {
        for (self.players.items, 0..) |*player, id| {
            if (std.mem.eql(u8, player.name.items, playerName)) return @intCast(id);
        }
        return null;
    }

    pub fn newPlayer(self: *Game, playerName: []const u8) !void {
        std.debug.assert(self.findPlayer(playerName) == null);
        try self.players.append(try Player.init(playerName, self.nextPlayerId, self.players.allocator));
        self.nextPlayerId += 1;
    }

    pub fn printPlayerNames(self: *Game) void {
        print("players:\n", .{});
        for (self.players.items) |*player| {
            print("{s} id:{d}\n", .{ player.name.items, player.id });
        }
    }

    pub fn deletePlayer(self: *Game, playerName: []const u8) error{OutOfMemory}!void {
        const arid = self.findPlayerArrayPosition(playerName).?;
        var pl = self.players.items[arid];
        const pid = pl.id;
        pl.deinit();
        _ = self.players.orderedRemove(arid);

        var toRemove = std.ArrayList(u32).init(self.units.allocator);
        defer toRemove.deinit();

        var it = self.units.valueIterator();
        while (it.next()) |unit| {
            if (unit.owner == pid) try toRemove.append(unit.id);
        }

        for (toRemove.items) |uid| {
            const x = self.units.get(uid).?.x;
            const y = self.units.get(uid).?.y;
            self.board.getField(x, y).unit_id = null;
            _ = self.units.remove(uid);
        }
    }

    pub fn clear(self: *Game) void {
        self.board.clear();

        for (self.players.items) |*player| {
            player.deinit();
        }
        self.players.shrinkRetainingCapacity(0);

        const alloc = self.units.allocator;
        self.units.deinit();
        self.units = std.AutoHashMap(u32, Unit).init(alloc);
    }

    pub fn newUnit(self: *Game, playerName: []const u8, unit: Unit) !void {
        var u = unit;
        var pl = self.findPlayer(playerName).?;
        try pl.newUnit(&u);
        try self.units.put(u.id, u);
        self.board.getField(u.x, u.y).unit_id = u.id;
    }

    pub fn deinit(self: *Game) void {
        for (self.players.items) |*player| {
            player.deinit();
        }
        self.players.deinit();

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

test "find_player" {
    const ally = testing.allocator;
    var game = try Game.init(10, 10, ally);
    defer game.deinit();
    try game.newPlayer("abc");

    const pl = game.findPlayer("abc").?;
    try std.testing.expect(std.mem.eql(u8, pl.name.items, "abc"));
}

test "clear" {
    const ally = testing.allocator;
    var game = try Game.init(10, 10, ally);
    defer game.deinit();
    try game.newPlayer("yeet");
    try game.newUnit("yeet", Unit{ .hp = 100, .id = 0, .owner = undefined, .x = 0, .y = 0 });
    game.clear();
    try std.testing.expectEqual(0, game.players.items.len);
    try std.testing.expectEqual(false, game.units.contains(0));
    try std.testing.expectEqual(null, game.board.getField(0, 0).unit_id);
}
