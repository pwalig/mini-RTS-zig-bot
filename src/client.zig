const std = @import("std");
const Stream = std.net.Stream;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Message = @import("message.zig");

const singleReadSize = 50;

const State = enum { Connected, Ready, Joined, Queued };

pub const Client = struct {
    recvBuffer: std.ArrayList(u8),
    stream: Stream,
    state: State,

    pub fn init(hostname: []const u8, port: u16, allocator: Allocator) !Client {
        const peer = try std.net.Address.parseIp4(hostname, port);
        const strm = try std.net.tcpConnectToAddress(peer);
        return Client{ .recvBuffer = std.ArrayList(u8).init(allocator), .stream = strm, .state = State.Connected };
    }
    pub fn read(self: *Client) !bool {
        try self.stream.reader().streamUntilDelimiter(self.recvBuffer.writer(), '\n', null);

        if (self.recvBuffer.items.len == 0) return false;
        print("{s}\n", .{self.recvBuffer.items});

        try self.parse();
        return true;
    }
    pub fn send(self: *Client, msg: []const u8) !void {
        var written = try self.stream.write(msg);
        while (written < msg.len) {
            written += try self.stream.write(msg[written..]);
        }
    }
    fn parse(self: *Client) !void {
        const t = self.recvBuffer.items[0];
        switch (t) {
            @intFromEnum(Message.Type.config) => {
                try self.send("nzigbot\nj\n");
            },
            @intFromEnum(Message.Type.tick) => {
                print("got a tick => time to make a move\n", .{});
            },
            else => {
                print("got invalid message type character {c}\n", .{t});
            },
        }
        self.recvBuffer.clearAndFree();
    }
    pub fn loop(self: *Client) void {
        while (self.read() catch false) {}
    }
    pub fn deinit(self: *Client) void {
        self.recvBuffer.deinit();
        self.stream.close();
    }
};
