const std = @import("std");
const Stream = std.net.Stream;
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const Message = @import("message.zig");

const singleReadSize = 50;

pub const Client = struct {
    recvBuffer: std.ArrayList(u8),
    stream: Stream,

    pub fn init(hostname: []const u8, port: u16, allocator: Allocator) !Client {
        const peer = try std.net.Address.parseIp4(hostname, port);
        const strm = try std.net.tcpConnectToAddress(peer);
        return Client{ .recvBuffer = std.ArrayList(u8).init(allocator), .stream = strm };
    }
    pub fn read(self: *Client) !bool {
        var readbuff: [singleReadSize]u8 = undefined;

        var rd = try self.stream.read(&readbuff);
        if (rd == 0) return false;
        print("{s}", .{readbuff[0..rd]});
        try self.recvBuffer.appendSlice(readbuff[0..rd]);

        while (rd == singleReadSize) {
            rd = try self.stream.read(&readbuff);
            print("{s}", .{readbuff[0..rd]});
            try self.recvBuffer.appendSlice(readbuff[0..rd]);
        }

        while (true == try self.parse()) {}

        return true;
    }
    pub fn send(self: *Client, msg: []const u8) !void {
        var written = try self.stream.write(msg);
        while (written < msg.len) {
            written += try self.stream.write(msg[written..]);
        }
    }
    fn parse(self: *Client) !bool {
        print("parse attempt\n", .{});
        var index: usize = 0;
        print("len: {d}\n", .{self.recvBuffer.items.len});
        for (self.recvBuffer.items) |byte| {
            index += 1;
            print("{c}", .{byte});
            if (byte == '\n') break;
        }
        if (self.recvBuffer.items[index - 1] != '\n' and index == self.recvBuffer.items.len) return false;
        try self.parseMsg(self.recvBuffer.items[0..index]);
        return true;
    }
    fn parseMsg(self: *Client, msg: []const u8) !void {
        const t = msg[0];
        print("{c} ", .{t});
        switch (t) {
            @intFromEnum(Message.Type.config) => {
                print("got a config => time to give self a name\n", .{});
                try self.send("nzigbot\nj\n");
            },
            @intFromEnum(Message.Type.tick) => {
                print("got a tick => time to make a move\n", .{});
            },
            else => {},
        }
    }
    pub fn loop(self: *Client) void {
        while (self.read() catch false) {}
    }
    pub fn deinit(self: *Client) void {
        self.recvBuffer.deinit();
        self.stream.close();
    }
};
