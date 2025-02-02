const std = @import("std");
const testing = std.testing;
const print = std.debug.print;
const distance = @import("coordinateOps.zig").distance;
const coords = @import("coordinateOps.zig").coords;
const Config = @import("Config.zig");

pub const Unit = struct {
    id: u32 = undefined,
    hp: u32 = undefined,
    x: u32 = undefined,
    y: u32 = undefined,
    owner: ?*Player = undefined,
};

pub const Field = struct {
    unit: ?*Unit,
    res_hp: ?u32,
};

pub const Board = struct {
    fields: []Field,
    x: u32,
    y: u32,
    allocator: std.mem.Allocator,

    pub fn init(x: u32, y: u32, allocator: std.mem.Allocator) !Board {
        const b = Board{ .fields = try allocator.alloc(Field, x * y), .x = x, .y = y, .allocator = allocator };
        errdefer allocator.free(b.fields);
        for (b.fields) |*f| {
            f.* = Field{ .unit = null, .res_hp = null };
        }
        return b;
    }

    pub fn getField(self: *Board, x: u32, y: u32) *Field {
        return &self.fields[x * self.y + y];
    }

    pub fn getClosestUnoccupiedResourceFieldPosition(self: *Board, x: u32, y: u32) ?coords {
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
                if (f.res_hp != null and f.unit == null) {
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
                self.fields[xi * self.y + yi].unit = null;
            }
        }
    }

    pub fn printUnits(self: *Board) void {
        print("units:\n", .{});
        for (0..self.y) |yi| {
            for (0..self.x) |xi| {
                const f = self.getField(@intCast(xi), @intCast(yi));
                if (f.unit) |u| {
                    print("{c}", .{u.owner.?.name.items[0]});
                } else print("-", .{});
            }
            print("\n", .{});
        }
    }

    pub fn printResources(self: *Board) void {
        print("resources:\n", .{});
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
    units: std.AutoHashMap(u32, *Unit),

    pub fn init(name: []const u8, allocator: std.mem.Allocator) !Player {
        var p = Player{ .name = try std.ArrayList(u8).initCapacity(allocator, name.len), .units = std.AutoHashMap(u32, *Unit).init(allocator) };
        p.name.appendSliceAssumeCapacity(name);
        return p;
    }

    pub fn deinit(self: *Player) void {
        self.name.deinit();
        self.units.deinit();
    }
};

pub const Game = struct {
    board: Board,
    players: std.ArrayList(*Player),
    units: std.AutoHashMap(u32, *Unit),

    unitsToWin: u32,
    resourceHp: u32,
    unitHp: u32,
    unitDamage: u32,
    allowedNameCharacters: []const u8,

    allocator: std.mem.Allocator,

    pub fn init(config: Config, allocator: std.mem.Allocator) !Game {
        var b = try Board.init(config.boardX, config.boardY, allocator);
        errdefer b.deinit();

        var p = try std.ArrayList(*Player).initCapacity(allocator, config.maxPlayers);
        errdefer p.deinit();

        return Game{
            .board = b,
            .units = std.AutoHashMap(u32, *Unit).init(allocator),
            .players = p,

            .unitsToWin = config.unitsToWin,
            .resourceHp = config.resourceHp,
            .unitHp = config.unitHp,
            .unitDamage = config.unitDamage,
            .allowedNameCharacters = try allocator.dupe(u8, config.allowedNameCharacters),

            .allocator = allocator,
        };
    }

    pub fn findPlayer(self: *Game, playerName: []const u8) ?*Player {
        for (self.players.items) |player| {
            if (std.mem.eql(u8, player.name.items, playerName)) return player;
        }
        return null;
    }

    fn findPlayerArrayPosition(self: *Game, playerName: []const u8) ?u32 {
        for (self.players.items, 0..) |player, id| {
            if (std.mem.eql(u8, player.name.items, playerName)) return @intCast(id);
        }
        return null;
    }

    pub fn newPlayer(self: *Game, playerName: []const u8) !void {
        std.debug.assert(self.findPlayer(playerName) == null);

        const player = try self.allocator.create(Player);
        errdefer self.allocator.destroy(player);
        player.* = try Player.init(playerName, self.players.allocator);

        try self.players.append(player);
    }

    pub fn deletePlayer(self: *Game, playerName: []const u8) error{OutOfMemory}!void {
        const arid = self.findPlayerArrayPosition(playerName).?;
        var player = self.players.items[arid];

        var toRemove = std.ArrayList(u32).init(self.allocator);
        defer toRemove.deinit();

        var it = self.units.valueIterator();
        while (it.next()) |unit| {
            if (unit.*.owner == player) try toRemove.append(unit.*.id);
        }

        for (toRemove.items) |uid| {
            self.deleteUnit(uid);
        }

        player.deinit();
        self.allocator.destroy(player);
        _ = self.players.orderedRemove(arid);
    }

    pub fn printPlayerNames(self: *Game) void {
        print("players:\n", .{});
        for (self.players.items) |player| {
            print("{s}\n", .{player.name.items});
        }
    }

    /// unit paremeter should be partially filed (with hp, x, y and id, owner should be left undefined)
    pub fn newUnit(self: *Game, playerName: []const u8, unit: Unit) !void {
        std.debug.assert(self.findPlayer(playerName) != null);

        const unitPtr = try self.allocator.create(Unit);
        errdefer self.allocator.destroy(unitPtr);
        unitPtr.* = unit;

        var player = self.findPlayer(playerName).?;
        unitPtr.owner = player;
        try player.units.put(unitPtr.id, unitPtr);
        try self.units.put(unitPtr.id, unitPtr);
        self.board.getField(unitPtr.x, unitPtr.y).unit = unitPtr;
    }

    pub fn deleteUnit(self: *Game, id: u32) void {
        const unit = self.units.get(id).?;
        const player = unit.owner.?;

        self.board.getField(unit.x, unit.y).unit = null;
        _ = player.units.remove(unit.id);
        _ = self.units.remove(id);

        self.allocator.destroy(unit);
    }

    pub fn clear(self: *Game) void {
        for (self.players.items) |player| {
            player.deinit();
            self.allocator.destroy(player);
        }
        self.players.shrinkRetainingCapacity(0);

        var it = self.units.valueIterator();
        while (it.next()) |unit| {
            self.allocator.destroy(unit.*);
        }
        self.units.deinit();
        self.units = std.AutoHashMap(u32, *Unit).init(self.allocator);

        self.board.clear();
    }

    pub fn deinit(self: *Game) void {
        for (self.players.items) |player| {
            player.deinit();
            self.allocator.destroy(player);
        }
        self.players.deinit();

        var it = self.units.valueIterator();
        while (it.next()) |unit| {
            self.allocator.destroy(unit.*);
        }
        self.units.deinit();

        self.board.deinit();
        self.allocator.free(self.allowedNameCharacters);
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
    try std.testing.expectEqual(null, game.board.getField(0, 0).unit);
}
