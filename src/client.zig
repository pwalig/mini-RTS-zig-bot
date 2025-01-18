const std = @import("std");
const Stream = std.net.Stream;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Message = @import("message.zig");
const Game = @import("game.zig").Game;

const singleReadSize = 50;

const State = enum { Connected, Ready, Joined, Queued };

pub const Client = struct {
    stream: Stream,
    state: State,
    game: ?Game = null,

    pub fn init(hostname: []const u8, port: u16) !Client {
        const peer = try std.net.Address.parseIp4(hostname, port);
        const strm = try std.net.tcpConnectToAddress(peer);
        return Client{ .stream = strm, .state = State.Connected };
    }
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
        print("{s}\n", .{buff.items});

        try self.parse(buff.items, allocator);
        return true;
    }
    pub fn send(self: *Client, msg: []const u8) !void {
        var written = try self.stream.write(msg);
        while (written < msg.len) {
            written += try self.stream.write(msg[written..]);
        }
    }
    fn parse(self: *Client, buff: []const u8, allocator: Allocator) !void {
        const t = buff[0];
        switch (t) {
            @intFromEnum(Message.Type.config) => {
                var it = std.mem.tokenizeAny(u8, buff[1..], " ,;\n");
                _ = it.next(); // skip millis
                _ = it.next(); // skip max players
                const x = try std.fmt.parseInt(u32, it.next().?, 10);
                const y = try std.fmt.parseInt(u32, it.next().?, 10);
                self.game = try Game.init(x, y, allocator);
                try self.send("nzigbot\nj\n");
                print("x: {d}, y: {d}\n", .{ self.game.?.board.x, self.game.?.board.y });
            },
            @intFromEnum(Message.Type.tick) => {
                print("got a tick => time to make a move\n", .{});
            },
            else => {
                print("got invalid message type character {c}\n", .{t});
            },
        }
    }
    pub fn loop(self: *Client, allocator: Allocator) void {
        while (self.read(allocator) catch false) {}
    }
    pub fn deinit(self: *Client) void {
        self.stream.close();
    }
};
