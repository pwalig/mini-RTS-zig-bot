const std = @import("std");
const net = std.net;
const print = std.debug.print;

const Client = @import("client.zig").Client;

const buffsize = 50;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();
    // The first (0 index) Argument is the path to the program.
    const program_name = args.next() orelse "mini-RTS-zig-bot";

    const host_value = args.next() orelse {
        print("usage {s} <host> <port> \n", .{program_name});
        return error.NoPort;
    };

    const port_value = args.next() orelse {
        print("usage {s} <host> <port> \n", .{program_name});
        return error.NoPort;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);

    var cli = try Client.init(host_value, port);
    defer cli.deinit();
    cli.loop(allocator);
}
