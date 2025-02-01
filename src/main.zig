const std = @import("std");
const net = std.net;
const print = std.debug.print;

const Client = @import("client.zig").Client;

const version = "1.0.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    const program_name = args.next() orelse "mini-RTS-zig-bot";

    const host_value = args.next() orelse {
        print("no host name or ip address provided\nusage {s} <host> <port>\n", .{program_name});
        return;
    };

    if (std.mem.eql(u8, host_value, "--version") or std.mem.eql(u8, host_value, "-v")) {
        try std.io.getStdOut().writer().print("{s}\n", .{version});
        return;
    }

    const port_value = args.next() orelse {
        print("no port provided\nusage {s} <host> <port>\n", .{program_name});
        return;
    };
    const port = try std.fmt.parseInt(u16, port_value, 10);

    var cli = try Client.init(host_value, port);
    defer cli.deinit();
    cli.loop(allocator);
}
