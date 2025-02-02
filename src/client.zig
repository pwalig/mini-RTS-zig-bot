const std = @import("std");
const Stream = std.net.Stream;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Message = @import("message.zig");
const game = @import("game.zig");
const Game = game.Game;
const Unit = game.Unit;
const Config = @import("Config.zig");
const coordOps = @import("coordinateOps.zig");
const NameIterator = @import("NameIterator.zig");

const singleReadSize = 50;

const State = enum { Connected, Ready, Joined, Queued };

pub const Client = struct {
    stream: Stream,
    state: State,
    game: ?Game = null,
    nameIter: NameIterator = undefined,

    /// sets up TCP connection
    /// after init .game is still null, .game will be initialized in .parse() if client recieves c message from server
    pub fn init(hostname: []const u8, port: u16) !Client {
        const peer = try std.net.Address.parseIp4(hostname, port);
        const strm = try std.net.tcpConnectToAddress(peer);
        try std.io.getStdOut().writer().print("connected to: {s}:{d}\n", .{ hostname, port });
        return Client{ .stream = strm, .state = State.Connected };
    }

    /// reads from socket stream until delimiter is found
    /// if message delimiter \n is found => calls self.parse()
    /// should block until finds delimiter, but instead throws error if delimiter not found in stream - TO FIX
    pub fn read(self: *Client, allocator: Allocator) !bool {
        var buff = std.ArrayList(u8).init(allocator);
        defer buff.deinit();
        self.stream.reader().streamUntilDelimiter(buff.writer(), '\n', null) catch {
            try std.io.getStdOut().writer().print("server closed the connection\n", .{});
            return false;
        };

        if (buff.items.len == 0) {
            try std.io.getStdOut().writer().print("server closed the connection\n", .{});
            return false;
        }
        // print("MSG: {s}\n", .{buff.items});

        try self.parse(buff.items, allocator);
        return true;
    }

    /// sends msg to server in a blocking manner
    pub fn send(self: *Client, msg: []const u8) !void {
        var written = try self.stream.write(msg);
        while (written < msg.len) {
            written += try self.stream.write(msg[written..]);
        }
    }

    /// parses the messages and takes appropriate action
    fn parse(self: *Client, buff: []const u8, allocator: Allocator) !void {
        const t = buff[0];
        switch (t) {
            @intFromEnum(Message.Type.config) => {
                if (self.state == State.Connected) {
                    var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                    const c = Config{
                        .millis = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .maxPlayers = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .boardX = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .boardY = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .unitsToWin = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .startResources = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .resourceHp = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .unitHp = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .unitDamage = try std.fmt.parseUnsigned(u32, it.next().?, 10),
                        .allowedNameCharacters = it.next().?,
                    };

                    self.game = try Game.init(c, allocator);

                    self.nameIter = NameIterator.init(self.game.?.allowedNameCharacters).?;

                    try self.send("n");
                    try self.send(self.nameIter.current());
                    print("requested name: {s}\n", .{self.nameIter.current()});
                    try self.send("\n");
                }
            },
            @intFromEnum(Message.Type.yes) => {
                if (self.state == State.Connected) {
                    self.state = State.Ready;
                    try std.io.getStdOut().writer().print("named self: {s}\njoining...\n", .{self.nameIter.current()});
                    try self.send("j\n");
                }
            },
            @intFromEnum(Message.Type.no) => {
                if (self.state == State.Connected) {
                    const newName = self.nameIter.next();
                    if (newName) |name| {
                        try self.send("n");
                        try self.send(name);
                        try self.send("\n");
                        print("requested name: {s}\n", .{name});
                    } else {
                        try std.io.getStdOut().writer().print("unable to set a name\nlook into mini-rts-server .config file and make sure characters z, i, g, b, o, t are set as valid name characters or contact your mini-rts-server administrator\nalso make sure not too many zigbots are playing at the same time\n", .{});
                        return error.UnableToNameSelf;
                    }
                }
            },
            @intFromEnum(Message.Type.queue) => {
                self.state = State.Queued;
                try std.io.getStdOut().writer().print("waiting in queue ...\n", .{});
            },
            @intFromEnum(Message.Type.players) => {
                self.state = State.Joined;
                try std.io.getStdOut().writer().print("joined the game\n", .{});

                var it0 = std.mem.tokenizeAny(u8, buff[1..], ";");
                const playerCount = try std.fmt.parseUnsigned(u32, it0.next().?, 10); // player count

                for (0..playerCount) |_| {
                    var it1 = std.mem.tokenizeAny(u8, it0.next().?[0..], ",");

                    var itintro = std.mem.tokenizeAny(u8, it1.next().?[0..], " ");
                    const playerName = itintro.next().?; // player name
                    const playerUnitsCount = try std.fmt.parseUnsigned(u32, itintro.next().?, 10);

                    try self.game.?.newPlayer(playerName);

                    for (0..playerUnitsCount) |_| {
                        var it3 = std.mem.tokenizeAny(u8, it1.next().?[0..], " ");

                        var unit = Unit{};
                        unit.id = try std.fmt.parseUnsigned(u32, it3.next().?, 10);
                        unit.x = try std.fmt.parseUnsigned(u32, it3.next().?, 10);
                        unit.y = try std.fmt.parseUnsigned(u32, it3.next().?, 10);
                        unit.hp = try std.fmt.parseUnsigned(u32, it3.next().?, 10);
                        try self.game.?.newUnit(playerName, unit);
                    }
                }
                self.game.?.printPlayerNames();
                self.game.?.board.printUnits();
            },
            @intFromEnum(Message.Type.resources) => {
                var it0 = std.mem.tokenizeAny(u8, buff[1..], ";");

                const resourceCount = try std.fmt.parseUnsigned(u32, it0.next().?, 10);

                for (0..resourceCount) |_| {
                    var it1 = std.mem.tokenizeAny(u8, it0.next().?, " ");
                    self.game.?.board.getField(
                        try std.fmt.parseUnsigned(u32, it1.next().?, 10),
                        try std.fmt.parseUnsigned(u32, it1.next().?, 10),
                    ).res_hp = try std.fmt.parseUnsigned(u32, it1.next().?, 10);
                }
                self.game.?.board.printResources();
            },
            @intFromEnum(Message.Type.new_resource) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                const x = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const y = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const hp = try std.fmt.parseUnsigned(u32, it.next().?, 10);

                self.game.?.board.getField(x, y).res_hp = hp;
            },
            @intFromEnum(Message.Type.unit) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                const playerName = it.next().?; // player name
                const id = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const x = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const y = try std.fmt.parseUnsigned(u32, it.next().?, 10);

                try self.game.?.newUnit(playerName, Unit{ .id = id, .x = x, .y = y, .hp = self.game.?.unitHp });
            },
            @intFromEnum(Message.Type.leave) => {
                const playerName = buff[1..]; // player name
                if (std.mem.eql(u8, playerName, self.nameIter.current())) {
                    try std.io.getStdOut().writer().print("lost all units\nrejoining...\n", .{});
                    self.game.?.clear();
                    self.state = State.Ready;
                    try self.send("j\n");
                } else {
                    try self.game.?.deletePlayer(playerName);
                }
            },
            @intFromEnum(Message.Type.lost) => {
                const playerName = buff[1..]; // player name
                try std.io.getStdOut().writer().print("lost the game to {s}\nrejoining...\n", .{playerName});
                self.game.?.clear();
                self.state = State.Ready;
                try self.send("j\n");
            },
            @intFromEnum(Message.Type.win) => {
                const playerName = buff[1..]; // player name
                std.debug.assert(std.mem.eql(u8, playerName, self.nameIter.current()));
                try std.io.getStdOut().writer().print("won the game\nrejoining...\n", .{});
                self.game.?.clear();
                self.state = State.Ready;
                try self.send("j\n");
            },
            @intFromEnum(Message.Type.move) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                const id = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const x = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const y = try std.fmt.parseUnsigned(u32, it.next().?, 10);

                const unit = self.game.?.units.get(id).?;
                self.game.?.board.getField(unit.x, unit.y).unit = null;
                unit.x = x;
                unit.y = y;
                self.game.?.board.getField(x, y).unit = unit;
            },
            @intFromEnum(Message.Type.attack) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                _ = try std.fmt.parseUnsigned(u32, it.next().?, 10); // id 1
                const id2 = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const hp = try std.fmt.parseUnsigned(u32, it.next().?, 10);

                if (hp == 0) {
                    self.game.?.deleteUnit(id2);
                } else {
                    self.game.?.units.get(id2).?.hp = hp;
                }
            },
            @intFromEnum(Message.Type.mine) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " \n");

                const id = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const hp = try std.fmt.parseUnsigned(u32, it.next().?, 10);
                const unit = self.game.?.units.get(id).?;

                self.game.?.board.getField(unit.x, unit.y).res_hp = if (hp == 0) null else hp;
            },
            @intFromEnum(Message.Type.join) => {
                try self.game.?.newPlayer(buff[1..]);
            },
            @intFromEnum(Message.Type.tick) => {
                const player = self.game.?.findPlayer(self.nameIter.current()).?;
                var it = player.units.valueIterator();
                while (it.next()) |unit| {
                    const max_len = 10; // TO DO figure out max_len from config sent by server
                    var buf: [max_len]u8 = undefined;

                    if (self.game.?.board.getField(unit.*.x, unit.*.y).res_hp != null) {
                        try self.send("d");
                        try self.send(try std.fmt.bufPrint(&buf, "{}", .{unit.*.id}));
                        try self.send("\n");
                    } else {
                        const fieldc = self.game.?.board.getClosestUnoccupiedResourceFieldPosition(unit.*.x, unit.*.y);
                        if (fieldc) |fc| {
                            const cds = coordOps.towards(unit.*.x, unit.*.y, fc.x, fc.y);
                            try self.send("m");
                            try self.send(try std.fmt.bufPrint(&buf, "{}", .{unit.*.id}));
                            try self.send(" ");
                            try self.send(try std.fmt.bufPrint(&buf, "{}", .{cds.x}));
                            try self.send(" ");
                            try self.send(try std.fmt.bufPrint(&buf, "{}", .{cds.y}));
                            try self.send("\n");
                        }
                    }
                }
            },
            else => {},
        }
    }

    /// client loop
    /// runs forever or until an error is thrown somewere
    pub fn loop(self: *Client, allocator: Allocator) void {
        while (self.read(allocator) catch false) {}
    }

    pub fn deinit(self: *Client) void {
        self.stream.close();
        self.game.?.deinit();
    }
};

test "string_test" {
    var name = [8]u8{ 'z', 'i', 'g', '-', 'b', 'o', 't', '0' };
    name[7] = '1';
    try std.testing.expect(std.mem.eql(u8, name[0..], "zig-bot1"));
}
