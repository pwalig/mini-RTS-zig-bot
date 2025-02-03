const std = @import("std");
const net = std.net;
const print = std.debug.print;

const Client = @import("client.zig").Client;
const HelpMessage = @import("HelpMessage.zig");

const version = "1.1.0";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();

    const program_name = args.next() orelse "mini-RTS-zig-bot";

    const host_value = args.next() orelse {
        try std.io.getStdOut().writer().print("no host provided\n", .{});
        try HelpMessage.printHelpMessage(program_name);
        return;
    };

    if (std.mem.eql(u8, host_value, "-v") or std.mem.eql(u8, host_value, "--version")) {
        if (args.next()) |option| {
            try std.io.getStdOut().writer().print("unnecessary additional option: {s}\n", .{option});
            try HelpMessage.printHelpMessage(program_name);
        } else try std.io.getStdOut().writer().print("{s}\n", .{version});
        return;
    } else if (std.mem.eql(u8, host_value, "-h") or std.mem.eql(u8, host_value, "--help")) {
        if (args.next()) |option| try std.io.getStdOut().writer().print("unnecessary additional option: {s}\n", .{option});
        try HelpMessage.printHelpMessage(program_name);
        return;
    }

    const port_value = args.next() orelse {
        try std.io.getStdOut().writer().print("no port provided\n", .{});
        try HelpMessage.printHelpMessage(program_name);
        return;
    };

    if (args.next()) |option| {
        try std.io.getStdOut().writer().print("unnecessary additional option: {s}\nrunModeOptions are not supported\n", .{option});
        try HelpMessage.printHelpMessage(program_name);
        return;
    }

    const port = std.fmt.parseInt(u16, port_value, 10) catch {
        try std.io.getStdOut().writer().print("invalid port number {s}\n", .{port_value});
        try HelpMessage.printHelpMessage(program_name);
        return;
    };

    var cli = try Client.init(host_value, port, null);
    defer cli.deinit();
    cli.loop(allocator);
}
